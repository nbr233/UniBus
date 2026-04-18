from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    StudentProfileViewSet,
    RouteViewSet,
    VehicleViewSet,
    BusViewSet,
    TicketViewSet,
    NoticeViewSet,
    SOSAlertViewSet,
    MasterRouteViewSet,
    get_route_suggestions,
    validate_ticket,
    recharge_wallet,
    vendor_stats,
    vendor_demand,
    vendor_add_checker,
    custom_login
)

# Register ViewSets with the router
router = DefaultRouter()
router.register(r'students', StudentProfileViewSet)
router.register(r'master-routes', MasterRouteViewSet)
router.register(r'routes', RouteViewSet, basename='route')
router.register(r'vehicles', VehicleViewSet, basename='vehicle')
router.register(r'buses', BusViewSet, basename='bus')
router.register(r'tickets', TicketViewSet, basename='ticket')
router.register(r'notices', NoticeViewSet, basename='notice')
router.register(r'sos', SOSAlertViewSet, basename='sos')

urlpatterns = [
    path('', include(router.urls)),
    path('suggestions/', get_route_suggestions, name='route-suggestions'),
    path('validate-ticket/', validate_ticket, name='validate-ticket'),
    path('recharge-wallet/', recharge_wallet, name='recharge-wallet'),
    path('vendor/stats/', vendor_stats, name='vendor-stats'),
    path('vendor/demand/', vendor_demand, name='vendor-demand'),
    path('vendor/checkers/', vendor_add_checker, name='vendor-checkers'),
    path('login/', custom_login, name='custom-login'),
]