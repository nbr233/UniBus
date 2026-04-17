import uuid
from datetime import timedelta
from django.db import transaction
from django.db.models import F
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view, action
from .models import StudentProfile, Route, Vehicle, Bus, Ticket, Notice, SOSAlert
from .serializers import (
    StudentProfileSerializer, 
    RouteSerializer,
    VehicleSerializer,
    BusSerializer, 
    TicketSerializer, 
    NoticeSerializer, 
    SOSAlertSerializer
)


class RouteViewSet(viewsets.ModelViewSet):
    queryset = Route.objects.all()
    serializer_class = RouteSerializer

class VehicleViewSet(viewsets.ModelViewSet):
    queryset = Vehicle.objects.all()
    serializer_class = VehicleSerializer

class BusViewSet(viewsets.ModelViewSet):
    serializer_class = BusSerializer
    queryset = Bus.objects.all().order_by('-date', '-departure_time')

    def perform_create(self, serializer):
        # When a bus is dispatched, mark the vehicle as unavailable
        vehicle = serializer.validated_data.get('vehicle')
        route = serializer.validated_data.get('route')
        total_seats = serializer.validated_data.get('total_seats', 40)

        if vehicle:
            vehicle.is_available = False
            vehicle.save()
        
        # Save the bus trip
        bus = serializer.save()

        # Automatically link waiting passengers for this route to this bus
        waiting_tickets = Ticket.objects.filter(
            route=route,
            status='Active',
            bus_assigned__isnull=True
        ).order_by('booked_at')[:total_seats]

        assigned_count = waiting_tickets.count()
        
        # Bulk update tickets to link them to the bus
        for ticket in waiting_tickets:
            ticket.bus_assigned = bus
            ticket.save()

        # Update the bus with the remaining seats
        bus.available_seats = total_seats - assigned_count
        bus.save()

    @action(detail=True, methods=['post'])
    def complete_trip(self, request, pk=None):
        bus = self.get_object()
        bus.status = 'Completed'
        if bus.vehicle:
            bus.vehicle.is_available = True
            bus.vehicle.save()
        bus.save()
        
        # Mark all tickets for this bus as used
        Ticket.objects.filter(bus_assigned=bus, status='Active').update(status='Used')
        
        return Response({'status': 'Trip completed and vehicle released'})


# 3. Ticket ViewSet
class TicketViewSet(viewsets.ModelViewSet):
    serializer_class = TicketSerializer

    def get_queryset(self):
        """
        Receives full email from Flutter (e.g. student@diu.edu.bd).
        Looks up StudentProfile by email, then filters tickets accordingly.
        """
        identifier = self.request.query_params.get('student_id')  # Expects full email
        show_history = self.request.query_params.get('history', 'false').lower() == 'true'

        if not identifier:
            return Ticket.objects.none()

        # Look up student by email if '@' present, otherwise by student_id
        try:
            if "@" in identifier:
                student = StudentProfile.objects.get(email=identifier)
            else:
                student = StudentProfile.objects.get(student_id=identifier)
        except StudentProfile.DoesNotExist:
            return Ticket.objects.none()

        # Filter at the database level — avoids the N+1 query problem
        cutoff = timezone.now() - timedelta(hours=1)

        if show_history:
            return Ticket.objects.filter(user=student, booked_at__lt=cutoff).order_by('-booked_at')

        return Ticket.objects.filter(user=student, booked_at__gte=cutoff).order_by('-booked_at')

    def create(self, request, *args, **kwargs):
        """
        Expects from Flutter: { "email": "...", "bus_id": 1 }
        Looks up StudentProfile by email and books the ticket.
        Uses atomic transaction to prevent race conditions.
        """
        user_email = request.data.get('email')
        route_id = request.data.get('route_id')

        if not user_email or not route_id:
            return Response(
                {"error": "email and route_id are required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            student = StudentProfile.objects.get(email=user_email)
        except StudentProfile.DoesNotExist:
            return Response(
                {"error": "Profile not found. Please complete your registration."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            route = Route.objects.get(id=route_id)
        except Route.DoesNotExist:
            return Response(
                {"error": "Route not found"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check if student already has an active ticket
        existing_tickets = Ticket.objects.filter(user=student, route=route).order_by('-booked_at')
        for t in existing_tickets:
            if t.is_active:
                return Response(
                    {"error": "You already have an active ticket for this route."},
                    status=status.HTTP_400_BAD_REQUEST
                )

        if student.wallet_balance < route.fare:
            return Response(
                {"error": f"Insufficient wallet balance. Fare is ৳{route.fare}, but your balance is ৳{student.wallet_balance}."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                student.wallet_balance -= route.fare
                student.save()

                unique_b_id = f"UB-{uuid.uuid4().hex[:8].upper()}"
                ticket = Ticket.objects.create(
                    user=student,
                    route=route,
                    booking_id=unique_b_id
                )

            serializer = self.get_serializer(ticket)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        except Exception as e:
            print(f"--- Critical Error: {str(e)} ---")
            return Response(
                {"error": "An internal error occurred"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# 4. Checker Ticket Validation API
@api_view(['POST'])
def validate_ticket(request):
    """
    Expects { "bus_id_code": "123456", "booking_id": "UB-XXXXXX" }
    Validates the ticket and updates its status to 'Used'.
    """
    bus_id_code = request.data.get('bus_id_code')
    booking_id = request.data.get('booking_id')

    if not bus_id_code or not booking_id:
        return Response({"error": "bus_id_code and booking_id are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        # Check if bus code is valid
        bus = Bus.objects.get(bus_id_code=bus_id_code)
    except Bus.DoesNotExist:
        return Response({"error": "Invalid Bus ID code"}, status=status.HTTP_404_NOT_FOUND)

    try:
        # Check if ticket exists
        ticket = Ticket.objects.get(booking_id=booking_id)
    except Ticket.DoesNotExist:
        return Response({"error": "Ticket not found"}, status=status.HTTP_404_NOT_FOUND)

    # Validation Logic
    if ticket.route != bus.route:
        return Response({"error": "Ticket does not match this bus route"}, status=status.HTTP_400_BAD_REQUEST)

    if ticket.status != 'Active':
        return Response({"error": f"Ticket is already {ticket.status}"}, status=status.HTTP_400_BAD_REQUEST)

    with transaction.atomic():
        ticket.status = 'Used'
        ticket.bus_assigned = bus
        ticket.save()

        # Update available seats if any
        if bus.available_seats > 0:
            bus.available_seats = F('available_seats') - 1
            bus.save()

    return Response({
        "message": "Ticket validation successful!",
        "student_name": f"{ticket.user.first_name} {ticket.user.last_name}",
        "student_id": ticket.user.student_id,
        "booking_id": ticket.booking_id
    }, status=status.HTTP_200_OK)


# 5. Route Suggestions API
@api_view(['GET'])
def get_route_suggestions(request):
    boarding_points = list(Route.objects.values_list('boarding_point', flat=True).distinct())
    dropping_points = list(Route.objects.values_list('dropping_point', flat=True).distinct())

    return Response({
        'boarding': boarding_points,
        'dropping': dropping_points
    })

# 6. Student Profile ViewSet (lookup by email)
class StudentProfileViewSet(viewsets.ModelViewSet):
    queryset = StudentProfile.objects.all()
    serializer_class = StudentProfileSerializer
    lookup_field = 'email'


# 7. Notice ViewSet
class NoticeViewSet(viewsets.ModelViewSet):
    """Students can read notices. Vendors can create them."""
    queryset = Notice.objects.all().order_by('-created_at')
    serializer_class = NoticeSerializer


# 8. SOS Alert ViewSet
class SOSAlertViewSet(viewsets.ModelViewSet):
    """Students can create SOS alerts. Vendor can resolve them via Admin."""
    queryset = SOSAlert.objects.all().order_by('-created_at')
    serializer_class = SOSAlertSerializer

    def create(self, request, *args, **kwargs):
        user_email = request.data.get('email')
        message = request.data.get('message', 'Emergency SOS')
        
        if not user_email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)
            
        try:
            student = StudentProfile.objects.get(email=user_email)
            alert = SOSAlert.objects.create(student=student, message=message)
            return Response(SOSAlertSerializer(alert).data, status=status.HTTP_201_CREATED)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Student profile not found"}, status=status.HTTP_404_NOT_FOUND)


# 9. Recharge Wallet API (For Vendor)
@api_view(['POST'])
def recharge_wallet(request):
    student_id = request.data.get('student_id')
    amount = request.data.get('amount')

    if not student_id or amount is None:
        return Response({"error": "student_id and amount are required"}, status=status.HTTP_400_BAD_REQUEST)

    from decimal import Decimal, InvalidOperation
    try:
        amount = Decimal(str(amount))
        if amount <= 0:
            return Response({"error": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST)
    except (ValueError, InvalidOperation):
        return Response({"error": "Invalid amount format"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        student = StudentProfile.objects.get(student_id=student_id)
        student.wallet_balance += amount
        student.save()
        return Response({
            "message": "Wallet recharged successfully",
            "student_name": f"{student.first_name} {student.last_name}",
            "new_balance": student.wallet_balance
        }, status=status.HTTP_200_OK)
    except StudentProfile.DoesNotExist:
        return Response({"error": "Student with this ID not found"}, status=status.HTTP_404_NOT_FOUND)

# 10. Vendor Dashboard APIs
@api_view(['GET'])
def vendor_stats(request):
    today = timezone.now().date()
    
    total_tickets_today = Ticket.objects.filter(booked_at__date=today).count()
    waiting_passengers = Ticket.objects.filter(status='Active', bus_assigned__isnull=True).count()
    active_fleet = Bus.objects.filter(status='Active').count()
    sos_alerts = SOSAlert.objects.filter(status='Pending').count()

    return Response({
        "total_tickets_today": total_tickets_today,
        "waiting_passengers": waiting_passengers,
        "active_fleet": active_fleet,
        "sos_alerts": sos_alerts
    })

@api_view(['GET'])
def vendor_demand(request):
    """Returns routes with active waiting passengers."""
    routes = Route.objects.all()
    demand_data = []

    for route in routes:
        waiting = Ticket.objects.filter(route=route, status='Active', bus_assigned__isnull=True).count()
        if waiting > 0:
            demand_data.append({
                "route_id": route.id,
                "route_name": route.name,
                "boarding": route.boarding_point,
                "dropping": route.dropping_point,
                "waiting_count": waiting
            })

    return Response(demand_data)

@api_view(['POST'])
def vendor_add_checker(request):
    """Vendor adds a checker with a specific password."""
    email = request.data.get('email')
    password = request.data.get('password')
    first_name = request.data.get('first_name')
    last_name = request.data.get('last_name')
    student_id = request.data.get('student_id')
    mobile = request.data.get('mobile_number', '')

    if not all([email, password, first_name, last_name, student_id]):
        return Response({"error": "Missing required fields (email, password, name, id)"}, status=status.HTTP_400_BAD_REQUEST)

    if StudentProfile.objects.filter(email=email).exists():
        return Response({"error": "A user with this email already exists"}, status=status.HTTP_400_BAD_REQUEST)

    profile = StudentProfile.objects.create(
        email=email,
        password=password, # In real app, use make_password
        first_name=first_name,
        last_name=last_name,
        student_id=student_id,
        mobile_number=mobile,
        role='Checker',
        firebase_uid='STAFF_' + uuid.uuid4().hex[:10]
    )

    return Response({
        "message": "Checker added successfully. They can now login with these credentials.",
        "checker_id": profile.student_id
    }, status=status.HTTP_201_CREATED)

@api_view(['POST'])
def custom_login(request):
    """Custom login for Checkers/Staff who don't use Firebase."""
    email = request.data.get('email')
    password = request.data.get('password')

    try:
        student = StudentProfile.objects.get(email=email)
        if student.password == password:
            return Response({
                "message": "Login Successful",
                "email": student.email,
                "role": student.role,
                "first_name": student.first_name
            }, status=status.HTTP_200_OK)
        else:
            return Response({"error": "Invalid password"}, status=status.HTTP_401_UNAUTHORIZED)
    except StudentProfile.DoesNotExist:
        return Response({"error": "User not found"}, status=status.HTTP_404_NOT_FOUND)