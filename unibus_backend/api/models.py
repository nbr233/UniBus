from django.db import models
import requests
from django.utils import timezone
from datetime import timedelta, date
import random
import string


def generate_bus_id():
    """Generate a random 6-character alphanumeric code for the Checker login ID."""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))


class StudentProfile(models.Model):
    ROLE_CHOICES = (
        ('Student', 'Student'),
        ('Checker', 'Checker'),
        ('Vendor', 'Vendor'),
    )
    student_id = models.CharField(max_length=20, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    mobile_number = models.CharField(max_length=15, blank=True, default='')
    email = models.EmailField(unique=True)
    firebase_uid = models.CharField(max_length=255, unique=True)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='Student')
    wallet_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    profile_picture = models.URLField(blank=True, null=True)
    password = models.CharField(max_length=128, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        # 🔥 Sync balance to Firebase Realtime Database for Live Updates
        try:
            fb_url = f"https://unibus-app-e8e4b-default-rtdb.firebaseio.com/wallets/{self.student_id}.json"
            requests.patch(fb_url, json={
                "balance": float(self.wallet_balance),
                "student_name": f"{self.first_name} {self.last_name}",
                "last_updated": timezone.now().isoformat()
            }, timeout=3)
        except Exception as e:
            print(f"Firebase Sync Warning: {e}")

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.student_id})"


class Route(models.Model):
    name = models.CharField(max_length=100)
    boarding_point = models.CharField(max_length=100)
    dropping_point = models.CharField(max_length=100)
    schedule_time = models.TimeField(null=True, blank=True)
    fare = models.DecimalField(max_digits=8, decimal_places=2, default=10.00)

    def __str__(self):
        return f"{self.name} ({self.boarding_point} → {self.dropping_point})"


class Vehicle(models.Model):
    bus_number = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=100)
    total_seats = models.IntegerField(default=40)
    is_available = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.name} ({self.bus_number})"


class Bus(models.Model):
    """A Bus trip dispatched on a specific day for a specific route."""
    route = models.ForeignKey(Route, on_delete=models.CASCADE, related_name='buses')
    vehicle = models.ForeignKey(Vehicle, on_delete=models.SET_NULL, null=True, blank=True)
    bus_number = models.CharField(max_length=50, default="TBA")
    departure_time = models.TimeField(null=True, blank=True)
    date = models.DateField(default=date.today)
    # 6-char code used by Checker to login
    bus_id_code = models.CharField(max_length=6, unique=True, default=generate_bus_id)
    total_seats = models.IntegerField(default=40)
    available_seats = models.IntegerField(default=40)
    status = models.CharField(max_length=20, default='Active')  # Active, Completed

    @property
    def formatted_time(self):
        if self.departure_time:
            return self.departure_time.strftime("%I:%M %p")
        return "Dispatching Soon"

    def __str__(self):
        return f"Bus [{self.bus_id_code}] on {self.route.name} ({self.date})"


class Ticket(models.Model):
    STATUS_CHOICES = (
        ('Active', 'Active'),
        ('Used', 'Used'),
        ('Expired', 'Expired'),
    )
    user = models.ForeignKey(StudentProfile, on_delete=models.CASCADE)
    route = models.ForeignKey(Route, on_delete=models.CASCADE, null=True)
    bus_assigned = models.ForeignKey(Bus, on_delete=models.SET_NULL, null=True, blank=True)
    booking_id = models.CharField(max_length=50, unique=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Active')
    travel_date = models.DateField(default=date.today)
    booked_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Ticket {self.booking_id} — {self.user.student_id} [{self.status}]"


class Notice(models.Model):
    title = models.CharField(max_length=200)
    message = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(
        StudentProfile, on_delete=models.SET_NULL, null=True, blank=True,
        limit_choices_to={'role': 'Vendor'}
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.title


class SOSAlert(models.Model):
    STATUS_CHOICES = (
        ('Pending', 'Pending'),
        ('Resolved', 'Resolved'),
    )
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE)
    message = models.TextField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='Pending')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"SOS by {self.student.student_id} — {self.status}"