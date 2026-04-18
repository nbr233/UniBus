from django.contrib import admin
from .models import StudentProfile, Route, Bus, Ticket, Notice, SOSAlert, MasterRoute

class RouteInline(admin.TabularInline):
    model = Route
    extra = 3

@admin.register(MasterRoute)
class MasterRouteAdmin(admin.ModelAdmin):
    verbose_name = "Create Route & Fare"
    verbose_name_plural = "1. Create Routes & Fares"
    list_display = ('name', 'boarding_point', 'dropping_point', 'fare')
    search_fields = ('name', 'boarding_point', 'dropping_point')
    inlines = [RouteInline]

@admin.register(Route)
class RouteAdmin(admin.ModelAdmin):
    verbose_name = "Define Schedule"
    verbose_name_plural = "2. Define Schedules"
    list_display = ('master_route', 'schedule_time', 'get_boarding', 'get_dropping', 'get_fare')
    list_filter = ('master_route',)

    def get_boarding(self, obj): return obj.boarding_point
    get_boarding.short_description = 'Boarding'
    
    def get_dropping(self, obj): return obj.dropping_point
    get_dropping.short_description = 'Dropping'
    
    def get_fare(self, obj): return obj.fare
    get_fare.short_description = 'Fare (৳)'

@admin.register(StudentProfile)
class StudentProfileAdmin(admin.ModelAdmin):
    list_display = ('student_id', 'first_name', 'last_name', 'role', 'wallet_balance')
    search_fields = ('student_id', 'email', 'mobile_number')
    list_filter = ('role',)

@admin.register(Bus)
class BusAdmin(admin.ModelAdmin):
    list_display = ('bus_id_code', 'bus_number', 'master_route', 'departure_time', 'date', 'status')
    search_fields = ('bus_id_code', 'bus_number', 'master_route__name')
    list_filter = ('date', 'status')

@admin.register(Ticket)
class TicketAdmin(admin.ModelAdmin):
    list_display = ('booking_id', 'user_student_id', 'bus_info', 'status', 'booked_at')
    search_fields = ('booking_id', 'user__student_id', 'user__email')
    list_filter = ('status', 'booked_at')

    def user_student_id(self, obj):
        return obj.user.student_id
    user_student_id.short_description = 'Student ID'

    def bus_info(self, obj):
        return str(obj.bus_assigned) if obj.bus_assigned else "Not Assigned"
    bus_info.short_description = 'Assigned Bus'

@admin.register(Notice)
class NoticeAdmin(admin.ModelAdmin):
    list_display = ('title', 'created_by', 'created_at')
    search_fields = ('title',)

@admin.register(SOSAlert)
class SOSAlertAdmin(admin.ModelAdmin):
    list_display = ('student', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('student__student_id',)