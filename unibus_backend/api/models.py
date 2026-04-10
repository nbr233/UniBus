from django.db import models
from django.utils import timezone
from datetime import timedelta


class StudentProfile(models.Model):
    # id হলো auto BigInt PK (ডাটাবেস স্ক্রিনশট অনুযায়ী)
    # student_id আলাদা CharField — primary key না
    student_id = models.CharField(max_length=20, unique=True)
    first_name = models.CharField(max_length=100)
    last_name = models.CharField(max_length=100)
    mobile_number = models.CharField(max_length=15)
    email = models.EmailField(unique=True)
    firebase_uid = models.CharField(max_length=255, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.student_id})"


class Bus(models.Model):
    name = models.CharField(max_length=100, default="Not Assigned")
    bus_number = models.CharField(max_length=50, default="TBA")
    route = models.CharField(max_length=100)
    boarding_point = models.CharField(max_length=100)
    dropping_point = models.CharField(max_length=100)
    departure_time = models.TimeField()
    total_seats = models.IntegerField(default=40)
    available_seats = models.IntegerField(default=40)

    @property
    def formatted_time(self):
        return self.departure_time.strftime("%I:%M %p")

    def __str__(self):
        return f"{self.formatted_time} - {self.boarding_point} to {self.dropping_point}"


class Ticket(models.Model):
    # ForeignKey — int id দিয়ে join হবে (StudentProfile.id)
    user = models.ForeignKey(StudentProfile, on_delete=models.CASCADE)
    bus = models.ForeignKey(Bus, on_delete=models.SET_NULL, null=True)
    booking_id = models.CharField(max_length=50, unique=True)
    booked_at = models.DateTimeField(auto_now_add=True)

    @property
    def is_active(self):
        # timedelta সরাসরি import করা হয়েছে — timezone.timedelta ভুল ছিল
        return timezone.now() < self.booked_at + timedelta(hours=1)

    def __str__(self):
        return f"Ticket {self.booking_id} - {self.user.student_id}"