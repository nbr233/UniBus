from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    StudentProfileViewSet, 
    BusViewSet, 
    TicketViewSet, # নতুন ভিউসেট ইমপোর্ট করো
    get_route_suggestions
)

# রাউটার সেটআপ
router = DefaultRouter()
router.register(r'students', StudentProfileViewSet)
router.register(r'buses', BusViewSet, basename='bus') 
# টিকিটের জন্য নতুন রাউট রেজিস্টার করা হলো
router.register(r'tickets', TicketViewSet, basename='ticket') 

urlpatterns = [
    path('', include(router.urls)),
    path('suggestions/', get_route_suggestions, name='route-suggestions'),
]