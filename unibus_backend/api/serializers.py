from rest_framework import serializers
from .models import StudentProfile, Route, Vehicle, Bus, Ticket, Notice, SOSAlert


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        # firebase_uid is intentionally excluded — should not be exposed to clients
        fields = ['id', 'student_id', 'first_name', 'last_name', 'mobile_number', 'email', 'role', 'wallet_balance', 'profile_picture', 'created_at']


class RouteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Route
        fields = '__all__'


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = '__all__'


class BusSerializer(serializers.ModelSerializer):
    formatted_time = serializers.ReadOnlyField()
    route_details = RouteSerializer(source='route', read_only=True)
    vehicle_details = VehicleSerializer(source='vehicle', read_only=True)

    class Meta:
        model = Bus
        fields = '__all__'


class NoticeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notice
        fields = '__all__'


class SOSAlertSerializer(serializers.ModelSerializer):
    student_id = serializers.CharField(source='student.student_id', read_only=True)

    class Meta:
        model = SOSAlert
        fields = '__all__'


class TicketSerializer(serializers.ModelSerializer):
    route_details = RouteSerializer(source='route', read_only=True)
    bus_details = BusSerializer(source='bus_assigned', read_only=True)
    is_active = serializers.ReadOnlyField()

    class Meta:
        model = Ticket
        fields = [
            'id',
            'user',
            'route',
            'route_details',
            'bus_assigned',
            'bus_details',
            'booking_id',
            'booked_at',
            'status',
            'is_active',
        ]