import uuid
from django.db import transaction
from django.db.models import F
from rest_framework import viewsets, status
from rest_framework.response import Response
from rest_framework.decorators import api_view
from .models import StudentProfile, Bus, Ticket
from .serializers import StudentProfileSerializer, BusSerializer, TicketSerializer


# ১. স্টুডেন্ট প্রোফাইল ভিউসেট
class StudentProfileViewSet(viewsets.ModelViewSet):
    queryset = StudentProfile.objects.all()
    serializer_class = StudentProfileSerializer


# ২. বাস ভিউসেট (সার্চ লজিকসহ)
class BusViewSet(viewsets.ModelViewSet):
    serializer_class = BusSerializer

    def get_queryset(self):
        queryset = Bus.objects.all()
        boarding = self.request.query_params.get('boarding')
        dropping = self.request.query_params.get('dropping')

        if boarding:
            queryset = queryset.filter(boarding_point__icontains=boarding)
        if dropping:
            queryset = queryset.filter(dropping_point__icontains=dropping)

        return queryset


# ৩. টিকেট ভিউসেট
class TicketViewSet(viewsets.ModelViewSet):
    serializer_class = TicketSerializer

    def get_queryset(self):
        """
        Flutter থেকে full email আসে (যেমন reachad22205101708@diu.edu.bd)।
        সেই email দিয়ে StudentProfile খুঁজে, তারপর টিকেট ফিল্টার করা হয়।
        """
        identifier = self.request.query_params.get('student_id')  # এখন full email আসবে
        show_history = self.request.query_params.get('history', 'false').lower() == 'true'

        if not identifier:
            return Ticket.objects.none()

        # Email দিয়ে student খোঁজা (@ থাকলে email, না থাকলে student_id)
        try:
            if "@" in identifier:
                student = StudentProfile.objects.get(email=identifier)
            else:
                student = StudentProfile.objects.get(student_id=identifier)
        except StudentProfile.DoesNotExist:
            return Ticket.objects.none()

        tickets = Ticket.objects.filter(user=student).order_by('-booked_at')

        # Active vs History
        active_ids = [t.id for t in tickets if t.is_active]
        history_ids = [t.id for t in tickets if not t.is_active]

        if show_history:
            return Ticket.objects.filter(id__in=history_ids).order_by('-booked_at')

        return Ticket.objects.filter(id__in=active_ids).order_by('-booked_at')

    def create(self, request, *args, **kwargs):
        """
        Flutter থেকে আসে: { "email": "...", "bus_id": 1 }
        Email দিয়ে StudentProfile খুঁজে টিকেট বুক করা হয়।
        Atomic transaction দিয়ে race condition এড়ানো হয়েছে।
        """
        user_email = request.data.get('email')
        b_id = request.data.get('bus_id')

        if not user_email or not b_id:
            return Response(
                {"error": "email and bus_id are required"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            student = StudentProfile.objects.get(email=user_email)
        except StudentProfile.DoesNotExist:
            print(f"--- Error: Profile with email '{user_email}' not found! ---")
            return Response(
                {"error": "Profile not found. Please complete your registration."},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            bus = Bus.objects.get(id=b_id)
        except Bus.DoesNotExist:
            return Response(
                {"error": "Bus slot not found"},
                status=status.HTTP_400_BAD_REQUEST
            )

        # একই বাসে আগে থেকে active টিকেট আছে কিনা চেক
        existing_tickets = Ticket.objects.filter(user=student, bus=bus).order_by('-booked_at')
        for t in existing_tickets:
            if t.is_active:
                return Response(
                    {"error": "You already have an active ticket for this slot."},
                    status=status.HTTP_400_BAD_REQUEST
                )

        try:
            with transaction.atomic():
                # Atomic seat check — race condition এড়াতে F() ব্যবহার
                updated = Bus.objects.filter(
                    id=b_id,
                    available_seats__gt=0
                ).update(available_seats=F('available_seats') - 1)

                if not updated:
                    return Response(
                        {"error": "No seats available in this slot"},
                        status=status.HTTP_400_BAD_REQUEST
                    )

                unique_b_id = f"UB-{uuid.uuid4().hex[:8].upper()}"
                ticket = Ticket.objects.create(
                    user=student,
                    bus=bus,
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


# ৪. রুট সাজেশন API
@api_view(['GET'])
def get_route_suggestions(request):
    boarding_points = list(Bus.objects.values_list('boarding_point', flat=True).distinct())
    dropping_points = list(Bus.objects.values_list('dropping_point', flat=True).distinct())

    return Response({
        'boarding': boarding_points,
        'dropping': dropping_points
    })

class StudentProfileViewSet(viewsets.ModelViewSet):
    queryset = StudentProfile.objects.all()
    serializer_class = StudentProfileSerializer
    lookup_field = 'email'