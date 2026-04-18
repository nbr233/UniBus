import uuid
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from django.db import transaction
from django.db.models import F
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view, action
from .models import StudentProfile, Route, Vehicle, Bus, Ticket, Notice, SOSAlert, MasterRoute
from .serializers import (
    StudentProfileSerializer,
    RouteSerializer,
    VehicleSerializer,
    BusSerializer,
    TicketSerializer,
    NoticeSerializer,
    SOSAlertSerializer,
    MasterRouteSerializer
)


# ================================================================
# MasterRoute ViewSet
# ================================================================
class MasterRouteViewSet(viewsets.ModelViewSet):
    queryset = MasterRoute.objects.all()
    serializer_class = MasterRouteSerializer


# ================================================================
# 1. Route ViewSet
# ================================================================
class RouteViewSet(viewsets.ModelViewSet):
    queryset = Route.objects.all()
    serializer_class = RouteSerializer


# ================================================================
# 2. Student Profile ViewSet
# ================================================================
class StudentProfileViewSet(viewsets.ModelViewSet):
    queryset = StudentProfile.objects.all()
    serializer_class = StudentProfileSerializer
    lookup_field = 'email'
    lookup_value_regex = '[^/]+'

    def get_queryset(self):
        identifier = self.request.query_params.get('student_id')
        email = self.request.query_params.get('email')
        if email:
            return StudentProfile.objects.filter(email=email)
        if identifier:
            return StudentProfile.objects.filter(student_id=identifier)
        return StudentProfile.objects.all()


# ================================================================
# 3. Vehicle ViewSet — supports ?available=true filter
# ================================================================
class VehicleViewSet(viewsets.ModelViewSet):
    serializer_class = VehicleSerializer

    def get_queryset(self):
        qs = Vehicle.objects.all()
        available_param = self.request.query_params.get('available')
        if available_param is not None:
            qs = qs.filter(is_available=(available_param.lower() == 'true'))
        return qs


# ================================================================
# 4. Bus ViewSet — Dynamic Dispatch with Concurrency Control
# ================================================================
class BusViewSet(viewsets.ModelViewSet):
    serializer_class = BusSerializer
    queryset = Bus.objects.all().order_by('-date', '-id')

    def perform_create(self, serializer):
        """
        On dispatch:
        1. Mark vehicle unavailable.
        2. Assign pending tickets via Nearest-Time logic.
        3. select_for_update() prevents race conditions.
        """
        vehicle = serializer.validated_data.get('vehicle')
        master_route = serializer.validated_data.get('master_route')
        departure_time = serializer.validated_data.get('departure_time')
        total_seats = serializer.validated_data.get('total_seats', 40)
        target_date = serializer.validated_data.get('date', date.today())

        if vehicle:
            vehicle.is_available = False
            vehicle.save(update_fields=['is_available'])

        bus = serializer.save()

        with transaction.atomic():
            waiting_tickets = Ticket.objects.select_for_update().filter(
                master_route=master_route,
                status='Active',
                bus_assigned__isnull=True,
                travel_date=target_date
            )

            if departure_time:
                tickets_list = list(waiting_tickets)
                bus_dt = datetime.combine(target_date, departure_time)

                def get_diff(t):
                    if t.desired_time:
                        t_dt = datetime.combine(target_date, t.desired_time)
                        return abs((bus_dt - t_dt).total_seconds())
                    return 999999  # No preferred time — lowest priority

                tickets_list.sort(key=get_diff)
                assigned_tickets = tickets_list[:total_seats]
            else:
                # Fallback: FIFO
                assigned_tickets = list(waiting_tickets.order_by('booked_at')[:total_seats])

            assigned_count = 0
            for ticket in assigned_tickets:
                ticket.bus_assigned = bus
                ticket.save(update_fields=['bus_assigned'])
                assigned_count += 1

        bus.available_seats = max(0, total_seats - assigned_count)
        bus.save(update_fields=['available_seats'])

    @action(detail=True, methods=['post'])
    def complete_trip(self, request, pk=None):
        """Mark trip complete, release vehicle, expire unboarded tickets."""
        bus = self.get_object()
        bus.status = 'Completed'
        bus.save(update_fields=['status'])

        if bus.vehicle:
            bus.vehicle.is_available = True
            bus.vehicle.save(update_fields=['is_available'])

        # Assigned-but-not-boarded tickets => Expired
        Ticket.objects.filter(bus_assigned=bus, status='Active').update(status='Expired')

        return Response({'message': f'Trip {bus.bus_id_code} completed. Vehicle released.'})


# ================================================================
# 5. Ticket ViewSet — Schedule-Free Booking
# ================================================================
class TicketViewSet(viewsets.ModelViewSet):
    serializer_class = TicketSerializer

    def get_queryset(self):
        identifier = self.request.query_params.get('student_id')
        show_history = self.request.query_params.get('history', 'false').lower() == 'true'

        if not identifier:
            return Ticket.objects.none()

        try:
            student = (
                StudentProfile.objects.get(email=identifier)
                if '@' in identifier
                else StudentProfile.objects.get(student_id=identifier)
            )
        except StudentProfile.DoesNotExist:
            return Ticket.objects.none()

        if show_history:
            return Ticket.objects.filter(
                user=student, status__in=['Active', 'Used', 'Expired']
            ).order_by('-booked_at')

        return Ticket.objects.filter(
            user=student, status='Active', travel_date=date.today()
        ).order_by('-booked_at')

    @transaction.atomic
    def create(self, request, *args, **kwargs):
        user_email = request.data.get('user_email')
        master_route_id = request.data.get('master_route_id')
        desired_time_str = request.data.get('desired_time')
        travel_date_str = request.data.get('travel_date', date.today().strftime('%Y-%m-%d'))

        if not user_email or not master_route_id:
            return Response(
                {'error': 'user_email and master_route_id are required'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            student = StudentProfile.objects.select_for_update().get(email=user_email)
            master_route = MasterRoute.objects.get(id=master_route_id)
        except StudentProfile.DoesNotExist:
            return Response({'error': 'Student profile not found'}, status=status.HTTP_404_NOT_FOUND)
        except MasterRoute.DoesNotExist:
            return Response({'error': 'Route not found'}, status=status.HTTP_404_NOT_FOUND)

        desired_time = None
        if desired_time_str:
            try:
                if 'AM' in desired_time_str.upper() or 'PM' in desired_time_str.upper():
                    desired_time = datetime.strptime(desired_time_str, '%I:%M %p').time()
                else:
                    desired_time = datetime.strptime(desired_time_str, '%H:%M').time()
            except ValueError:
                return Response(
                    {'error': 'Invalid time format. Use HH:MM or HH:MM AM/PM'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        if student.wallet_balance < master_route.fare:
            return Response(
                {'error': f'Insufficient balance. Need {master_route.fare}, have {student.wallet_balance}'},
                status=status.HTTP_400_BAD_REQUEST
            )

        student.wallet_balance -= master_route.fare
        student.save()

        ticket = Ticket.objects.create(
            user=student,
            master_route=master_route,
            desired_time=desired_time,
            travel_date=travel_date_str,
            booking_id='BK-' + uuid.uuid4().hex[:8].upper(),
            status='Active'
        )

        return Response(TicketSerializer(ticket).data, status=status.HTTP_201_CREATED)


# ================================================================
# 6. Validate Ticket (Checker API)
# ================================================================
@api_view(['POST'])
def validate_ticket(request):
    bus_id_code = request.data.get('bus_id_code', '').strip().upper()
    booking_id = request.data.get('booking_id', '').strip()

    if not bus_id_code or not booking_id:
        return Response(
            {'error': 'bus_id_code and booking_id are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        bus = Bus.objects.get(bus_id_code=bus_id_code)
    except Bus.DoesNotExist:
        return Response({'error': 'Invalid Bus Code. Bus not found.'}, status=status.HTTP_404_NOT_FOUND)

    try:
        ticket = Ticket.objects.select_related('user', 'master_route', 'bus_assigned').get(
            booking_id=booking_id
        )
    except Ticket.DoesNotExist:
        return Response({'error': 'Invalid Ticket ID. Ticket not found.'}, status=status.HTTP_404_NOT_FOUND)

    # Already used?
    if ticket.status == 'Used':
        return Response({'error': 'This ticket has already been used.'}, status=status.HTTP_400_BAD_REQUEST)

    # Expired?
    if ticket.status == 'Expired':
        return Response({'error': 'This ticket has expired.'}, status=status.HTTP_400_BAD_REQUEST)

    # Date check
    if ticket.travel_date != date.today():
        return Response(
            {'error': 'Ticket is not for today.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Bus must be assigned
    if ticket.bus_assigned is None:
        return Response({'error': 'No bus assigned to this ticket yet.'}, status=status.HTTP_400_BAD_REQUEST)

    # Strict bus matching
    if ticket.bus_assigned_id != bus.id:
        return Response(
            {'error': 'Wrong bus. Ticket is for Bus ' + ticket.bus_assigned.bus_id_code + '.'},
            status=status.HTTP_403_FORBIDDEN
        )

    # Seat capacity check
    if bus.available_seats <= 0:
        return Response({'error': 'Bus is full. No seats available.'}, status=status.HTTP_400_BAD_REQUEST)

    # All checks passed — mark used and decrement seat
    with transaction.atomic():
        ticket.status = 'Used'
        ticket.save(update_fields=['status'])
        Bus.objects.filter(pk=bus.pk).update(available_seats=F('available_seats') - 1)

    return Response({
        'message': 'Valid! Passenger boarded.',
        'student_name': ticket.user.first_name + ' ' + ticket.user.last_name,
        'student_id': ticket.user.student_id,
        'route': ticket.master_route.name if ticket.master_route else 'Unknown',
    })


# ================================================================
# 7. Notice ViewSet
# ================================================================
class NoticeViewSet(viewsets.ModelViewSet):
    queryset = Notice.objects.all().order_by('-created_at')
    serializer_class = NoticeSerializer


# ================================================================
# 8. SOS Alert ViewSet
# ================================================================
class SOSAlertViewSet(viewsets.ModelViewSet):
    serializer_class = SOSAlertSerializer

    def get_queryset(self):
        return SOSAlert.objects.all().order_by('-created_at')

    def create(self, request, *args, **kwargs):
        firebase_uid = request.data.get('firebase_uid')
        message = request.data.get('message', 'Emergency!')
        try:
            student = StudentProfile.objects.get(firebase_uid=firebase_uid)
        except StudentProfile.DoesNotExist:
            return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)
        alert = SOSAlert.objects.create(student=student, message=message)
        return Response(SOSAlertSerializer(alert).data, status=status.HTTP_201_CREATED)


# ================================================================
# 9. Wallet Recharge
# ================================================================
@api_view(['POST'])
def recharge_wallet(request):
    student_id = request.data.get('student_id', '').strip()
    amount_str = request.data.get('amount', '').strip()

    if not student_id or not amount_str:
        return Response({'error': 'student_id and amount are required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        amount = Decimal(str(amount_str))
        if amount <= 0:
            raise ValueError
    except (InvalidOperation, ValueError):
        return Response({'error': 'Invalid amount'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        student = StudentProfile.objects.get(student_id=student_id)
    except StudentProfile.DoesNotExist:
        return Response({'error': 'Student not found'}, status=status.HTTP_404_NOT_FOUND)

    student.wallet_balance += amount
    student.save()

    return Response({
        'message': 'Wallet recharged successfully.',
        'student_id': student.student_id,
        'new_balance': float(student.wallet_balance),
    })


# ================================================================
# 10. Route Suggestions
# ================================================================
@api_view(['GET'])
def get_route_suggestions(request):
    query = request.query_params.get('q', '').strip()
    if not query:
        return Response([])
    routes = Route.objects.filter(master_route__name__icontains=query).select_related('master_route')[:10]
    return Response([
        {
            'id': r.id,
            'name': r.master_route.name,
            'boarding_point': r.master_route.boarding_point,
            'dropping_point': r.master_route.dropping_point,
        }
        for r in routes
    ])


# ================================================================
# 11. Vendor Stats
# ================================================================
@api_view(['GET'])
def vendor_stats(request):
    today = date.today()
    return Response({
        'total_tickets_today': Ticket.objects.filter(travel_date=today).count(),
        'waiting_passengers': Ticket.objects.filter(
            status='Active', bus_assigned__isnull=True, travel_date=today
        ).count(),
        'active_fleet': Bus.objects.filter(status='Active', date=today).count(),
        'sos_alerts': SOSAlert.objects.filter(status='Pending').count(),
    })


# ================================================================
# 12. Vendor Demand Tracking (MasterRoute-based)
# ================================================================
@api_view(['GET'])
def vendor_demand(request):
    today = date.today()
    demand_data = []

    for m_route in MasterRoute.objects.all():
        waiting = Ticket.objects.filter(
            master_route=m_route, status='Active',
            bus_assigned__isnull=True, travel_date=today
        ).count()
        active_buses = Bus.objects.filter(
            master_route=m_route, status='Active', date=today
        ).count()

        demand_data.append({
            'route_id': m_route.id,
            'route_name': m_route.name,
            'boarding': m_route.boarding_point,
            'dropping': m_route.dropping_point,
            'waiting_count': waiting,
            'active_buses': active_buses,
            'needs_bus': waiting > 0 and active_buses == 0,
            'available_vehicles': Vehicle.objects.filter(is_available=True).count(),
        })

    demand_data.sort(key=lambda x: -x['waiting_count'])
    return Response(demand_data)


# ================================================================
# 13. Vendor — Add / List Checkers
# ================================================================
@api_view(['GET', 'POST'])
def vendor_add_checker(request):
    if request.method == 'GET':
        checkers = StudentProfile.objects.filter(role='Checker').values(
            'student_id', 'first_name', 'last_name', 'email', 'mobile_number', 'created_at'
        )
        return Response(list(checkers))

    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()
    first_name = request.data.get('first_name', '').strip()
    last_name = request.data.get('last_name', '').strip()
    student_id = request.data.get('student_id', '').strip()
    mobile = request.data.get('mobile_number', '').strip()

    if not all([email, password, first_name, last_name, student_id]):
        return Response(
            {'error': 'email, password, first_name, last_name, student_id are all required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if StudentProfile.objects.filter(email=email).exists():
        return Response({'error': 'A user with this email already exists'}, status=status.HTTP_400_BAD_REQUEST)

    if StudentProfile.objects.filter(student_id=student_id).exists():
        return Response({'error': 'A user with this student_id already exists'}, status=status.HTTP_400_BAD_REQUEST)

    from django.contrib.auth.hashers import make_password
    uid_suffix = uuid.uuid4().hex[:6]
    profile = StudentProfile.objects.create(
        student_id=student_id,
        first_name=first_name,
        last_name=last_name,
        email=email,
        mobile_number=mobile,
        password=make_password(password),
        role='Checker',
        firebase_uid='staff_' + student_id + '_' + uid_suffix
    )

    return Response({
        'message': 'Checker added successfully.',
        'checker_id': profile.student_id,
        'email': profile.email
    }, status=status.HTTP_201_CREATED)


# ================================================================
# 14. Custom Login (Checker / Staff)
# ================================================================
@api_view(['POST'])
def custom_login(request):
    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()

    if not email or not password:
        return Response({'error': 'Email and password are required'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        from django.contrib.auth.hashers import check_password as django_check_password
        student = StudentProfile.objects.get(email=email)

        if student.password and django_check_password(password, student.password):
            return Response({
                'message': 'Login successful',
                'email': student.email,
                'role': student.role,
                'first_name': student.first_name,
                'last_name': student.last_name,
                'student_id': student.student_id,
            }, status=status.HTTP_200_OK)
        else:
            return Response({'error': 'Invalid email or password'}, status=status.HTTP_401_UNAUTHORIZED)
    except StudentProfile.DoesNotExist:
        return Response({'error': 'No account found with this email'}, status=status.HTTP_404_NOT_FOUND)
