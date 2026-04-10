from django.contrib import admin
from .models import StudentProfile, Bus # এখানে Bus মডেলটি ইমপোর্ট করো

# StudentProfile রেজিস্টার করা
admin.site.register(StudentProfile)

# Bus মডেলটি রেজিস্টার করো যাতে অ্যাডমিন প্যানেলে দেখা যায়
admin.site.register(Bus)