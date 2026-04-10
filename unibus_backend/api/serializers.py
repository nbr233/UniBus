from rest_framework import serializers
from .models import StudentProfile, Bus, Ticket


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        fields = '__all__'


class BusSerializer(serializers.ModelSerializer):
    # formatted_time property টি JSON-এ দেখানোর জন্য
    formatted_time = serializers.ReadOnlyField()

    class Meta:
        model = Bus
        fields = '__all__'


class TicketSerializer(serializers.ModelSerializer):
    # বাসের পুরো ডিটেইলস টিকেটের সাথে আসবে (nested)
    bus_details = BusSerializer(source='bus', read_only=True)
    # is_active property
    is_active = serializers.ReadOnlyField()

    class Meta:
        model = Ticket
        fields = [
            'id',
            'user',
            'bus',
            'bus_details',
            'booking_id',
            'booked_at',
            'is_active',
        ]