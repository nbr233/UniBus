// ✅ URLs are managed centrally in config.js — এখানে কিছু পরিবর্তন করবেন না।
const API_BASE = CONFIG.API_BASE;
const FIREBASE_DB_URL = CONFIG.FIREBASE_DB_URL;

// Navigation Logic
document.querySelectorAll('.nav-item').forEach(button => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.nav-item').forEach(btn => btn.classList.remove('active'));
        button.classList.add('active');

        const targetId = button.getAttribute('data-target');
        document.querySelectorAll('.content-section').forEach(section => section.classList.remove('active'));
        document.getElementById(targetId).classList.add('active');
        document.getElementById('page-title').textContent = button.textContent.trim();

        if (targetId === 'dashboard') fetchStats();
        if (targetId === 'demand') { fetchDemand(); fetchActiveTrips(); }
        if (targetId === 'vehicles') fetchVehicles();
        if (targetId === 'routes') fetchRoutes();
        if (targetId === 'staff') fetchStaff();
        if (targetId === 'sos') fetchSOS();
    });
});

function showMessage(elementId, text, isSuccess) {
    const el = document.getElementById(elementId);
    el.textContent = text;
    el.style.display = 'block';
    el.className = `message ${isSuccess ? 'success' : 'error'}`;
    setTimeout(() => {
        el.style.display = 'none';
        el.className = 'message';
    }, 5000);
}

// 1. Dashboard Stats
async function fetchStats() {
    try {
        const response = await fetch(`${API_BASE}/vendor/stats/`);
        const stats = await response.json();
        document.getElementById('stat-tickets').textContent = stats.total_tickets_today;
        document.getElementById('stat-waiting').textContent = stats.waiting_passengers;
        document.getElementById('stat-fleet').textContent = stats.active_fleet;
        document.getElementById('stat-sos').textContent = stats.sos_alerts;
    } catch (error) {
        console.error('Error fetching stats:', error);
    }
}

// 2. Vehicles Management
document.getElementById('vehicle-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
        name: document.getElementById('vehicle-name').value,
        bus_number: document.getElementById('vehicle-number').value,
        total_seats: 40 // Default to 40, will be overridden at dispatch
    };
    try {
        const response = await fetch(`${API_BASE}/vehicles/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('vehicle-msg', 'Vehicle added to system!', true);
            document.getElementById('vehicle-form').reset();
            fetchVehicles();
        } else {
            const data = await response.json();
            showMessage('vehicle-msg', `Error: ${JSON.stringify(data)}`, false);
        }
    } catch (error) {
        showMessage('vehicle-msg', 'Network error.', false);
    }
});

async function fetchVehicles() {
    try {
        const response = await fetch(`${API_BASE}/vehicles/`);
        const list = await response.json();
        const tbody = document.querySelector('#vehicles-table tbody');
        tbody.innerHTML = '';
        list.forEach(v => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${v.name}</td><td>${v.bus_number}</td><td>${v.total_seats} ${v.is_available ? '<span class="status-badge status-Pending">Available</span>' : '<span class="status-badge status-SOS">In Use</span>'}</td>`;
            tbody.appendChild(tr);
        });
        
        // Also update the dispatch dropdown (Only Available)
        const dropdown = document.getElementById('dispatch-vehicle-id');
        dropdown.innerHTML = '<option value="">-- Select a Bus --</option>';
        list.filter(v => v.is_available).forEach(v => {
            const opt = document.createElement('option');
            opt.value = v.id;
            opt.dataset.seats = v.total_seats;
            opt.dataset.number = v.bus_number;
            opt.textContent = `${v.name} (${v.bus_number})`;
            dropdown.appendChild(opt);
        });
    } catch (error) {
        console.error('Error fetching vehicles:', error);
    }
}

// 3. Demand & Dispatch
async function fetchDemand() {
    try {
        const response = await fetch(`${API_BASE}/vendor/demand/`);
        const demand = await response.json();
        const tbody = document.querySelector('#demand-table tbody');
        tbody.innerHTML = '';
        if (demand.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#aaa;padding:24px">No active demand at the moment.</td></tr>';
        }
        demand.forEach(item => {
            const tr = document.createElement('tr');
            const needsBus = item.needs_bus;
            const statusBadge = needsBus
                ? `<span class="status-badge status-SOS">⚠️ Needs Bus</span>`
                : `<span class="status-badge status-Active">✅ Covered</span>`;
            tr.innerHTML = `
                <td><strong>${item.route_name}</strong><br><small>${item.boarding} &rarr; ${item.dropping}</small></td>
                <td><span class="status-badge status-Pending">${item.waiting_count} Waiting</span></td>
                <td>${item.active_buses} Bus(es)</td>
                <td>${statusBadge}</td>
                <td><button class="btn btn-small primary" onclick="showDispatchForm(${item.route_id}, '${item.route_name}')">Dispatch</button></td>
            `;
            tbody.appendChild(tr);
        });
        fetchVehicles();
    } catch (error) {
        console.error('Error fetching demand:', error);
    }
}

function showDispatchForm(routeId, routeName) {
    document.getElementById('dispatch-container').style.display = 'block';
    document.getElementById('dispatch-route-id').value = routeId;
    document.getElementById('dispatch-route-name').textContent = routeName;
    document.getElementById('dispatch-container').scrollIntoView({ behavior: 'smooth' });
}

document.getElementById('dispatch-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const routeId = document.getElementById('dispatch-route-id').value;
    const vehicleSelect = document.getElementById('dispatch-vehicle-id');
    const vehicleId = vehicleSelect.value;
    const vehicleOpt = vehicleSelect.options[vehicleSelect.selectedIndex];
    
    const capacity = document.getElementById('dispatch-capacity').value;
    const payload = {
        route: routeId,
        vehicle: vehicleId,
        bus_number: vehicleOpt.dataset.number,
        total_seats: capacity,
        available_seats: capacity,
        status: 'Active'
    };

    try {
        const response = await fetch(`${API_BASE}/buses/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        const data = await response.json();
        if (response.ok) {
            showMessage('dispatch-msg', `Success! Bus ID: ${data.bus_id_code}`, true);
            document.getElementById('dispatch-form').reset();
            setTimeout(() => {
                document.getElementById('dispatch-container').style.display = 'none';
                fetchDemand();
                fetchActiveTrips();
                fetchStats();
            }, 2000);
        }
    } catch (error) {
        showMessage('dispatch-msg', 'Network error.', false);
    }
});

async function fetchActiveTrips() {
    try {
        const response = await fetch(`${API_BASE}/buses/`);
        const trips = await response.json();
        const tbody = document.querySelector('#active-trips-table tbody');
        tbody.innerHTML = '';
        const active = trips.filter(t => t.status === 'Active');
        if (active.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#aaa;padding:24px">No active trips.</td></tr>';
        }
        active.forEach(t => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong style="font-size:18px;letter-spacing:3px;color:#2D6A4F">${t.bus_id_code}</strong><br><small>Give this to Checker</small></td>
                <td>${t.route_details ? t.route_details.name : '—'}</td>
                <td>${t.bus_number}</td>
                <td><span class="status-badge status-Active">${t.status}</span></td>
                <td><button class="btn btn-small secondary" onclick="completeTrip(${t.id})">Complete Trip</button></td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error('Error fetching active trips:', error);
    }
}

async function completeTrip(tripId) {
    try {
        const response = await fetch(`${API_BASE}/buses/${tripId}/complete_trip/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        if (response.ok) {
            fetchActiveTrips();
            fetchDemand();
            fetchVehicles();
        }
    } catch (error) {
        console.error('Error completing trip:', error);
    }
}

// 4. Routes Management (Centralized Logic with Edit Support)
let _allMasterRoutes = [];
let _allSchedules = [];

async function fetchMasterRoutes() {
    try {
        const response = await fetch(`${API_BASE}/master-routes/`);
        _allMasterRoutes = await response.json();
        
        // Populate Dropdown
        const dropdown = document.getElementById('master-route-dropdown');
        dropdown.innerHTML = '<option value="">-- Choose a Route --</option>';
        _allMasterRoutes.forEach(r => {
            const opt = document.createElement('option');
            opt.value = r.id;
            opt.textContent = r.name;
            opt.dataset.boarding = r.boarding_point;
            opt.dataset.dropping = r.dropping_point;
            opt.dataset.fare = r.fare;
            dropdown.appendChild(opt);
        });

        // Populate Master Routes Table
        const tbody = document.querySelector('#master-routes-table tbody');
        tbody.innerHTML = '';
        _allMasterRoutes.forEach(r => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${r.name}</strong><br><small>${r.boarding_point} &rarr; ${r.dropping_point}</small></td>
                <td>৳${r.fare}</td>
                <td>
                    <button class="btn-icon edit" onclick="editMasterRoute(${r.id})">✏️</button>
                </td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error('Error fetching master routes:', error);
    }
}

// Auto-fill logic for Step 2
document.getElementById('master-route-dropdown').addEventListener('change', (e) => {
    const opt = e.target.options[e.target.selectedIndex];
    if (opt.value) {
        document.getElementById('boarding-point').value = opt.dataset.boarding;
        document.getElementById('dropping-point').value = opt.dataset.dropping;
        document.getElementById('fare').value = `৳${opt.dataset.fare}`;
    } else {
        document.getElementById('boarding-point').value = '';
        document.getElementById('dropping-point').value = '';
        document.getElementById('fare').value = '';
    }
});

// Master Route Submit (Create or Update)
document.getElementById('master-route-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = document.getElementById('edit-master-id').value;
    const payload = {
        name: document.getElementById('master-route-name').value,
        boarding_point: document.getElementById('master-boarding').value,
        dropping_point: document.getElementById('master-dropping').value,
        fare: document.getElementById('master-fare').value
    };

    const url = id ? `${API_BASE}/master-routes/${id}/` : `${API_BASE}/master-routes/`;
    const method = id ? 'PUT' : 'POST';

    try {
        const response = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('master-route-msg', id ? 'Master Route Updated!' : 'Master Route Created!', true);
            cancelMasterEdit();
            fetchMasterRoutes();
            fetchRoutes(); // Update schedules table too as they might have changed visually
        }
    } catch (error) {
        showMessage('master-route-msg', 'Network error.', false);
    }
});

function editMasterRoute(id) {
    const route = _allMasterRoutes.find(r => r.id === id);
    if (!route) return;

    document.getElementById('edit-master-id').value = route.id;
    document.getElementById('master-route-name').value = route.name;
    document.getElementById('master-boarding').value = route.boarding_point;
    document.getElementById('master-dropping').value = route.dropping_point;
    document.getElementById('master-fare').value = route.fare;

    document.getElementById('master-submit-btn').textContent = "Update Master Route";
    document.getElementById('master-cancel-btn').style.display = "block";
}

function cancelMasterEdit() {
    document.getElementById('master-route-form').reset();
    document.getElementById('edit-master-id').value = "";
    document.getElementById('master-submit-btn').textContent = "Create Master Route";
    document.getElementById('master-cancel-btn').style.display = "none";
}
document.getElementById('master-cancel-btn').addEventListener('click', cancelMasterEdit);

// Schedule Submit (Create or Update)
document.getElementById('route-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const id = document.getElementById('edit-schedule-id').value;
    const payload = {
        master_route: document.getElementById('master-route-dropdown').value,
        schedule_time: document.getElementById('route-time').value
    };

    const url = id ? `${API_BASE}/routes/${id}/` : `${API_BASE}/routes/`;
    const method = id ? 'PUT' : 'POST';

    try {
        const response = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('route-msg', id ? 'Schedule Updated!' : 'Schedule Defined!', true);
            cancelScheduleEdit();
            fetchRoutes();
        }
    } catch (error) {
        showMessage('route-msg', 'Network error.', false);
    }
});

function editSchedule(id) {
    const sch = _allSchedules.find(s => s.id === id);
    if (!sch) return;

    document.getElementById('edit-schedule-id').value = sch.id;
    document.getElementById('master-route-dropdown').value = sch.master_route;
    
    // Trigger auto-fill
    const event = new Event('change');
    document.getElementById('master-route-dropdown').dispatchEvent(event);
    
    // Extract time (HH:mm) if it's HH:mm:ss
    const timeVal = sch.schedule_time ? sch.schedule_time.substring(0, 5) : "";
    document.getElementById('route-time').value = timeVal;

    document.getElementById('schedule-submit-btn').textContent = "Update Schedule";
    document.getElementById('schedule-cancel-btn').style.display = "block";
}

function cancelScheduleEdit() {
    document.getElementById('route-form').reset();
    document.getElementById('edit-schedule-id').value = "";
    document.getElementById('schedule-submit-btn').textContent = "Define Schedule";
    document.getElementById('schedule-cancel-btn').style.display = "none";
}
document.getElementById('schedule-cancel-btn').addEventListener('click', cancelScheduleEdit);

async function fetchRoutes() {
    try {
        const response = await fetch(`${API_BASE}/routes/`);
        _allSchedules = await response.json();
        const tbody = document.querySelector('#routes-list-table tbody');
        tbody.innerHTML = '';
        _allSchedules.forEach(r => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${r.name}</strong><br><small>${r.boarding_point} &rarr; ${r.dropping_point}</small></td>
                <td>${r.schedule_time_display || 'Flexible'}</td>
                <td>
                    <button class="btn-icon edit" onclick="editSchedule(${r.id})">✏️</button>
                </td>
            `;
            tbody.appendChild(tr);
        });
        fetchMasterRoutes(); // Sync dropdown
    } catch (error) {
        console.error('Error fetching routes:', error);
    }
}

// 5. Staff
document.getElementById('checker-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
        first_name: document.getElementById('staff-first-name').value,
        last_name: document.getElementById('staff-last-name').value,
        email: document.getElementById('staff-email').value,
        password: document.getElementById('staff-password').value,
        student_id: document.getElementById('staff-id').value,
        role: 'Checker'
    };
    try {
        const response = await fetch(`${API_BASE}/vendor/checkers/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('staff-msg', 'Checker registered!', true);
            document.getElementById('checker-form').reset();
            fetchStaff();
        }
    } catch (error) {
        showMessage('staff-msg', 'Network error.', false);
    }
});

async function fetchStaff() {
    try {
        // Use dedicated checkers endpoint
        const response = await fetch(`${API_BASE}/vendor/checkers/`);
        const checkers = await response.json();
        const tbody = document.querySelector('#staff-list-table tbody');
        tbody.innerHTML = '';
        if (checkers.length === 0) {
            tbody.innerHTML = '<tr><td colspan="3" style="text-align:center;color:#aaa;padding:24px">No checkers added yet.</td></tr>';
            return;
        }
        checkers.forEach(c => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${c.first_name} ${c.last_name}</strong></td>
                <td>${c.email}</td>
                <td>${c.student_id}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error('Error fetching staff:', error);
    }
}

// 6. Wallet
document.getElementById('recharge-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const studentId = document.getElementById('recharge-student-id').value;
    const amount = document.getElementById('recharge-amount').value;
    try {
        const response = await fetch(`${API_BASE}/recharge-wallet/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ student_id: studentId, amount: amount })
        });
        if (response.ok) {
            const data = await response.json();
            showMessage('recharge-msg', `Success! New Balance: ${data.new_balance}`, true);
            
            // 🔥 Live Sync to Firebase Realtime Database
            try {
                await fetch(`${FIREBASE_DB_URL}/wallets/${studentId}.json`, {
                    method: 'PATCH',
                    body: JSON.stringify({ balance: data.new_balance, last_updated: new Date().toISOString() })
                });
                console.log('Firebase sync successful');
            } catch (fbError) {
                console.error('Firebase sync failed:', fbError);
            }

            document.getElementById('recharge-form').reset();
        }
    } catch (error) {
        showMessage('recharge-msg', 'Network error.', false);
    }
});

// 7. SOS
async function fetchSOS() {
    try {
        const response = await fetch(`${API_BASE}/sos/`);
        const alerts = await response.json();
        const tbody = document.querySelector('#sos-table tbody');
        tbody.innerHTML = '';
        alerts.forEach(alert => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${alert.student_id}</strong></td>
                <td>${alert.message}<br><small>${new Date(alert.created_at).toLocaleString()}</small></td>
                <td><span class="status-badge status-${alert.status}">${alert.status}</span></td>
                <td>${alert.status === 'Pending' ? `<button class="btn btn-small secondary" onclick="resolveSOS(${alert.id})">Resolve</button>` : 'Resolved'}</td>
            `;
            tbody.appendChild(tr);
        });
    } catch (error) {
        console.error('Error fetching SOS:', error);
    }
}

async function resolveSOS(id) {
    try {
        const response = await fetch(`${API_BASE}/sos/${id}/`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ status: 'Resolved' })
        });
        if (response.ok) fetchSOS();
    } catch (error) {
        console.error('Error resolving SOS:', error);
    }
}

// 8. Notice
document.getElementById('notice-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
        title: document.getElementById('notice-title').value,
        message: document.getElementById('notice-message').value
    };
    try {
        const response = await fetch(`${API_BASE}/notices/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('notice-msg', 'Notice broadcasted!', true);
            document.getElementById('notice-form').reset();
        }
    } catch (error) {
        showMessage('notice-msg', 'Network error.', false);
    }
});

// Initial
fetchStats();
fetchRoutes();
fetchVehicles();
fetchSOS();
setInterval(fetchStats, 30000);
