from rest_framework import serializers
from .models import StudentProfile, Route, Vehicle, Bus, Ticket, Notice, SOSAlert, MasterRoute


class MasterRouteSerializer(serializers.ModelSerializer):
    class Meta:
        model = MasterRoute
        fields = '__all__'


class StudentProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = StudentProfile
        # firebase_uid and password intentionally excluded
        fields = [
            'id', 'student_id', 'first_name', 'last_name',
            'mobile_number', 'email', 'role', 'wallet_balance',
            'profile_picture', 'created_at', 'firebase_uid'
        ]
        read_only_fields = ['created_at']


class RouteSerializer(serializers.ModelSerializer):
    schedule_time_display = serializers.SerializerMethodField()

    class Meta:
        model = Route
        fields = [
            'id', 'master_route', 'schedule_time', 'schedule_time_display',
            'name', 'boarding_point', 'dropping_point', 'fare'
        ]

    def get_schedule_time_display(self, obj):
        if obj.schedule_time:
            return obj.schedule_time.strftime("%I:%M %p")
        return "Flexible"


class VehicleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Vehicle
        fields = '__all__'


class BusSerializer(serializers.ModelSerializer):
    formatted_time = serializers.ReadOnlyField()
    master_route_details = MasterRouteSerializer(source='master_route', read_only=True)
    vehicle_details = VehicleSerializer(source='vehicle', read_only=True)

    class Meta:
        model = Bus
        fields = '__all__'


class NoticeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notice
        fields = '__all__'


class SOSAlertSerializer(serializers.ModelSerializer):
    student_name = serializers.SerializerMethodField()
    student_id_display = serializers.CharField(source='student.student_id', read_only=True)

    class Meta:
        model = SOSAlert
        fields = '__all__'

    def get_student_name(self, obj):
        return f"{obj.student.first_name} {obj.student.last_name}"


class TicketSerializer(serializers.ModelSerializer):
    master_route_details = MasterRouteSerializer(source='master_route', read_only=True)
    bus_details = BusSerializer(source='bus_assigned', read_only=True)
    student_name = serializers.SerializerMethodField()

    class Meta:
        model = Ticket
        fields = [
            'id',
            'user',
            'student_name',
            'master_route',
            'master_route_details',
            'desired_time',
            'bus_assigned',
            'bus_details',
            'booking_id',
            'status',
            'travel_date',
            'booked_at',
        ]

    def get_student_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}"