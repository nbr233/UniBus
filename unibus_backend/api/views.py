import uuid
from datetime import date
from decimal import Decimal, InvalidOperation
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


# ─────────────────────────────────────────
# 1. Route ViewSet
# ─────────────────────────────────────────
class RouteViewSet(viewsets.ModelViewSet):
    queryset = Route.objects.all()
    serializer_class = RouteSerializer


# ─────────────────────────────────────────
# 2. Vehicle ViewSet
# ─────────────────────────────────────────
class VehicleViewSet(viewsets.ModelViewSet):
    queryset = Vehicle.objects.all()
    serializer_class = VehicleSerializer


# ─────────────────────────────────────────
# 3. Bus ViewSet (Trip Dispatch)
# ─────────────────────────────────────────
class BusViewSet(viewsets.ModelViewSet):
    serializer_class = BusSerializer
    queryset = Bus.objects.all().order_by('-date', '-id')

    def perform_create(self, serializer):
        """
        On dispatch:
        1. Mark vehicle as unavailable.
        2. FIFO-assign waiting passengers for this route (up to total_seats).
        3. Update available_seats on the bus.
        """
        vehicle = serializer.validated_data.get('vehicle')
        route = serializer.validated_data.get('route')
        total_seats = serializer.validated_data.get('total_seats', 40)

        if vehicle:
            vehicle.is_available = False
            vehicle.save(update_fields=['is_available'])

        bus = serializer.save()

        # FIFO assignment: oldest waiting tickets first
        waiting_tickets = Ticket.objects.filter(
            route=route,
            status='Active',
            bus_assigned__isnull=True,
            travel_date=date.today()
        ).order_by('booked_at')[:total_seats]

        assigned_count = 0
        for ticket in waiting_tickets:
            ticket.bus_assigned = bus
            ticket.save(update_fields=['bus_assigned'])
            assigned_count += 1

        bus.available_seats = max(0, total_seats - assigned_count)
        bus.save(update_fields=['available_seats'])

    @action(detail=True, methods=['post'])
    def complete_trip(self, request, pk=None):
        """Mark a bus trip as completed, release vehicle, mark tickets as Used."""
        bus = self.get_object()
        bus.status = 'Completed'
        bus.save(update_fields=['status'])

        if bus.vehicle:
            bus.vehicle.is_available = True
            bus.vehicle.save(update_fields=['is_available'])

        Ticket.objects.filter(
            bus_assigned=bus, status='Active'
        ).update(status='Used')

        return Response({'message': f'Trip {bus.bus_id_code} completed. Vehicle released.'})


# ─────────────────────────────────────────
# 4. Ticket ViewSet
# ─────────────────────────────────────────
class TicketViewSet(viewsets.ModelViewSet):
    serializer_class = TicketSerializer

    def get_queryset(self):
        """
        Returns tickets for a student identified by email or student_id.
        ?student_id=email&history=true  → Active + Used (all history)
        ?student_id=email               → Active tickets for today only
        """
        identifier = self.request.query_params.get('student_id')
        show_history = self.request.query_params.get('history', 'false').lower() == 'true'

        if not identifier:
            return Ticket.objects.none()

        try:
            if "@" in identifier:
                student = StudentProfile.objects.get(email=identifier)
            else:
                student = StudentProfile.objects.get(student_id=identifier)
        except StudentProfile.DoesNotExist:
            return Ticket.objects.none()

        if show_history:
            # Return all tickets (Active + Used) for history screen
            return Ticket.objects.filter(
                user=student,
                status__in=['Active', 'Used']
            ).order_by('-booked_at')

        # Active screen — today's active tickets only
        return Ticket.objects.filter(
            user=student,
            status='Active',
            travel_date=date.today()
        ).order_by('-booked_at')

    def create(self, request, *args, **kwargs):
        """
        Book a ticket.
        Body: { "email": "...", "route_id": 1 }
        Validates: wallet balance >= fare, no existing active ticket on route today.
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
                {"error": "Profile not found. Please complete your registration first."},
                status=status.HTTP_404_NOT_FOUND
            )

        try:
            route = Route.objects.get(id=route_id)
        except Route.DoesNotExist:
            return Response({"error": "Route not found"}, status=status.HTTP_404_NOT_FOUND)

        # Check for duplicate active ticket today
        existing = Ticket.objects.filter(
            user=student, route=route, status='Active', travel_date=date.today()
        ).exists()
        if existing:
            return Response(
                {"error": "You already have an active ticket for this route today."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Check wallet balance
        if student.wallet_balance < route.fare:
            return Response(
                {"error": f"Insufficient balance. Fare: ৳{route.fare} | Your balance: ৳{student.wallet_balance}"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            with transaction.atomic():
                # Deduct fare atomically
                StudentProfile.objects.filter(pk=student.pk).update(
                    wallet_balance=F('wallet_balance') - route.fare
                )
                student.refresh_from_db()
                # Trigger Firebase sync via save()
                student.save(update_fields=['wallet_balance'])

                booking_id = f"UB-{uuid.uuid4().hex[:8].upper()}"
                ticket = Ticket.objects.create(
                    user=student,
                    route=route,
                    booking_id=booking_id,
                    travel_date=date.today()
                )

            serializer = self.get_serializer(ticket)
            return Response(serializer.data, status=status.HTTP_201_CREATED)

        except Exception as e:
            return Response(
                {"error": f"Booking failed: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


# ─────────────────────────────────────────
# 5. Validate Ticket (Checker API)
# ─────────────────────────────────────────
@api_view(['POST'])
def validate_ticket(request):
    """
    Checker scans QR. Body: { "bus_id_code": "ABC123", "booking_id": "UB-XXXXXXXX" }
    Validates: ticket exists, active, correct bus, today's travel date.
    """
    bus_id_code = request.data.get('bus_id_code', '').strip().upper()
    booking_id = request.data.get('booking_id', '').strip()

    if not bus_id_code or not booking_id:
        return Response(
            {"error": "bus_id_code and booking_id are required"},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Validate bus
    try:
        bus = Bus.objects.get(bus_id_code=bus_id_code)
    except Bus.DoesNotExist:
        return Response({"error": "Invalid Bus ID. Please check the 6-character code."}, status=status.HTTP_404_NOT_FOUND)

    if bus.status == 'Completed':
        return Response({"error": "This bus trip is already completed."}, status=status.HTTP_400_BAD_REQUEST)

    # Validate ticket
    try:
        ticket = Ticket.objects.select_related('user', 'route', 'bus_assigned').get(booking_id=booking_id)
    except Ticket.DoesNotExist:
        return Response({"error": "Ticket not found. Invalid QR code."}, status=status.HTTP_404_NOT_FOUND)

    if ticket.status == 'Used':
        return Response({"error": "This ticket has already been used."}, status=status.HTTP_400_BAD_REQUEST)

    if ticket.status == 'Expired':
        return Response({"error": "This ticket has expired."}, status=status.HTTP_400_BAD_REQUEST)

    if ticket.travel_date != date.today():
        return Response(
            {"error": f"This ticket is for {ticket.travel_date}, not today."},
            status=status.HTTP_400_BAD_REQUEST
        )

    if ticket.route != bus.route:
        return Response(
            {"error": f"Ticket is for route '{ticket.route.name}', but this bus operates '{bus.route.name}'."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # All checks passed — mark as Used
    with transaction.atomic():
        ticket.status = 'Used'
        ticket.bus_assigned = bus
        ticket.save(update_fields=['status', 'bus_assigned'])

        if bus.available_seats > 0:
            Bus.objects.filter(pk=bus.pk).update(available_seats=F('available_seats') - 1)

    return Response({
        "message": "✅ Ticket Valid! Passenger boarded.",
        "student_name": f"{ticket.user.first_name} {ticket.user.last_name}",
        "student_id": ticket.user.student_id,
        "route": ticket.route.name,
        "booking_id": ticket.booking_id
    }, status=status.HTTP_200_OK)


# ─────────────────────────────────────────
# 6. Student Profile ViewSet
# ─────────────────────────────────────────
class StudentProfileViewSet(viewsets.ModelViewSet):
    queryset = StudentProfile.objects.all()
    serializer_class = StudentProfileSerializer
    lookup_field = 'email'


# ─────────────────────────────────────────
# 7. Notice ViewSet
# ─────────────────────────────────────────
class NoticeViewSet(viewsets.ModelViewSet):
    queryset = Notice.objects.all().order_by('-created_at')
    serializer_class = NoticeSerializer


# ─────────────────────────────────────────
# 8. SOS Alert ViewSet
# ─────────────────────────────────────────
class SOSAlertViewSet(viewsets.ModelViewSet):
    queryset = SOSAlert.objects.all().order_by('-created_at')
    serializer_class = SOSAlertSerializer

    def create(self, request, *args, **kwargs):
        user_email = request.data.get('email')
        message = request.data.get('message', 'Emergency SOS Alert')

        if not user_email:
            return Response({"error": "Email is required"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            student = StudentProfile.objects.get(email=user_email)
            alert = SOSAlert.objects.create(student=student, message=message)
            return Response(SOSAlertSerializer(alert).data, status=status.HTTP_201_CREATED)
        except StudentProfile.DoesNotExist:
            return Response({"error": "Student profile not found"}, status=status.HTTP_404_NOT_FOUND)


# ─────────────────────────────────────────
# 9. Recharge Wallet (Vendor)
# ─────────────────────────────────────────
@api_view(['POST'])
def recharge_wallet(request):
    """Vendor recharges a student wallet. Body: { "student_id": "...", "amount": 50 }"""
    student_id = request.data.get('student_id', '').strip()
    amount = request.data.get('amount')

    if not student_id or amount is None:
        return Response({"error": "student_id and amount are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        amount = Decimal(str(amount))
        if amount <= 0:
            return Response({"error": "Amount must be greater than 0"}, status=status.HTTP_400_BAD_REQUEST)
    except (ValueError, InvalidOperation):
        return Response({"error": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        with transaction.atomic():
            student = StudentProfile.objects.select_for_update().get(student_id=student_id)
            student.wallet_balance += amount
            student.save()  # triggers Firebase sync

        return Response({
            "message": "Wallet recharged successfully",
            "student_name": f"{student.first_name} {student.last_name}",
            "student_id": student.student_id,
            "new_balance": float(student.wallet_balance)
        }, status=status.HTTP_200_OK)
    except StudentProfile.DoesNotExist:
        return Response({"error": "Student with this ID not found"}, status=status.HTTP_404_NOT_FOUND)


# ─────────────────────────────────────────
# 10. Route Suggestions
# ─────────────────────────────────────────
@api_view(['GET'])
def get_route_suggestions(request):
    boarding = list(Route.objects.values_list('boarding_point', flat=True).distinct())
    dropping = list(Route.objects.values_list('dropping_point', flat=True).distinct())
    return Response({'boarding': boarding, 'dropping': dropping})


# ─────────────────────────────────────────
# 11. Vendor Stats
# ─────────────────────────────────────────
@api_view(['GET'])
def vendor_stats(request):
    today = date.today()
    total_tickets_today = Ticket.objects.filter(travel_date=today).count()
    waiting_passengers = Ticket.objects.filter(status='Active', bus_assigned__isnull=True, travel_date=today).count()
    active_fleet = Bus.objects.filter(status='Active', date=today).count()
    sos_alerts = SOSAlert.objects.filter(status='Pending').count()

    return Response({
        "total_tickets_today": total_tickets_today,
        "waiting_passengers": waiting_passengers,
        "active_fleet": active_fleet,
        "sos_alerts": sos_alerts
    })


# ─────────────────────────────────────────
# 12. Vendor Demand Tracking
# ─────────────────────────────────────────
@api_view(['GET'])
def vendor_demand(request):
    """Returns all routes with waiting passenger counts and available vehicles."""
    today = date.today()
    routes = Route.objects.all()
    demand_data = []

    for route in routes:
        waiting = Ticket.objects.filter(
            route=route, status='Active', bus_assigned__isnull=True, travel_date=today
        ).count()
        active_buses = Bus.objects.filter(route=route, status='Active', date=today).count()
        available_vehicles = Vehicle.objects.filter(is_available=True).count()

        demand_data.append({
            "route_id": route.id,
            "route_name": route.name,
            "boarding": route.boarding_point,
            "dropping": route.dropping_point,
            "waiting_count": waiting,
            "active_buses": active_buses,
            "needs_bus": waiting > 0 and active_buses == 0,
            "available_vehicles": available_vehicles
        })

    # Sort: routes needing buses first
    demand_data.sort(key=lambda x: (-x['waiting_count']))
    return Response(demand_data)


# ─────────────────────────────────────────
# 13. Vendor — Add Checker
# ─────────────────────────────────────────
@api_view(['GET', 'POST'])
def vendor_add_checker(request):
    if request.method == 'GET':
        checkers = StudentProfile.objects.filter(role='Checker').values(
            'student_id', 'first_name', 'last_name', 'email', 'mobile_number', 'created_at'
        )
        return Response(list(checkers))

    # POST — add new checker
    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()
    first_name = request.data.get('first_name', '').strip()
    last_name = request.data.get('last_name', '').strip()
    student_id = request.data.get('student_id', '').strip()
    mobile = request.data.get('mobile_number', '').strip()

    if not all([email, password, first_name, last_name, student_id]):
        return Response(
            {"error": "email, password, first_name, last_name, student_id are all required"},
            status=status.HTTP_400_BAD_REQUEST
        )

    if StudentProfile.objects.filter(email=email).exists():
        return Response({"error": "A user with this email already exists"}, status=status.HTTP_400_BAD_REQUEST)

    if StudentProfile.objects.filter(student_id=student_id).exists():
        return Response({"error": "A user with this student_id already exists"}, status=status.HTTP_400_BAD_REQUEST)

    from django.contrib.auth.hashers import make_password
    hashed_password = make_password(password)

    profile = StudentProfile.objects.create(
        student_id=student_id,
        first_name=first_name,
        last_name=last_name,
        email=email,
        mobile_number=mobile,
        password=hashed_password,
        role='Checker',
        firebase_uid=f"staff_{student_id}_{uuid.uuid4().hex[:6]}"
    )

    return Response({
        "message": f"Checker '{first_name} {last_name}' added successfully.",
        "checker_id": profile.student_id,
        "email": profile.email
    }, status=status.HTTP_201_CREATED)


# ─────────────────────────────────────────
# 14. Custom Login (Staff/Checker)
# ─────────────────────────────────────────
@api_view(['POST'])
def custom_login(request):
    """Login for Checkers/Staff who don't use Firebase Auth."""
    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()

    if not email or not password:
        return Response({"error": "Email and password are required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        from django.contrib.auth.hashers import check_password as django_check_password
        student = StudentProfile.objects.get(email=email)

        if student.password and django_check_password(password, student.password):
            return Response({
                "message": "Login successful",
                "email": student.email,
                "role": student.role,
                "first_name": student.first_name,
                "last_name": student.last_name,
                "student_id": student.student_id
            }, status=status.HTTP_200_OK)
        else:
            return Response({"error": "Invalid email or password"}, status=status.HTTP_401_UNAUTHORIZED)
    except StudentProfile.DoesNotExist:
        return Response({"error": "No account found with this email"}, status=status.HTTP_404_NOT_FOUND)