// ⚠️ change this to your production URL (e.g., https://your-app.onrender.com/api)
const API_BASE = 'http://192.168.0.106:8000/api';

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
        demand.forEach(item => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${item.route_name}</strong><br><small>${item.boarding} &rarr; ${item.dropping}</small></td>
                <td><span class="status-badge status-Pending">${item.waiting_count} Waiting</span></td>
                <td><button class="btn btn-small primary" onclick="showDispatchForm(${item.route_id}, '${item.route_name}')">Dispatch</button></td>
            `;
            tbody.appendChild(tr);
        });
        // Ensure vehicles are loaded for the dropdown
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
        trips.filter(t => t.status === 'Active').forEach(t => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${t.bus_id_code}</strong></td>
                <td>${t.route_details.name}</td>
                <td>${t.bus_number}</td>
                <td><span class="status-badge status-Active">${t.status}</span></td>
                <td><button class="btn btn-small secondary" onclick="completeTrip(${t.id})">Complete</button></td>
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

// 4. Routes
document.getElementById('route-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const payload = {
        name: document.getElementById('route-name').value,
        boarding_point: document.getElementById('boarding-point').value,
        dropping_point: document.getElementById('dropping-point').value,
        schedule_time: document.getElementById('route-time').value || null,
        fare: document.getElementById('fare').value
    };
    try {
        const response = await fetch(`${API_BASE}/routes/`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });
        if (response.ok) {
            showMessage('route-msg', 'Route defined!', true);
            document.getElementById('route-form').reset();
            fetchRoutes();
        }
    } catch (error) {
        showMessage('route-msg', 'Network error.', false);
    }
});

async function fetchRoutes() {
    try {
        const response = await fetch(`${API_BASE}/routes/`);
        const routes = await response.json();
        const tbody = document.querySelector('#routes-list-table tbody');
        tbody.innerHTML = '';
        routes.forEach(r => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${r.name}</strong></td>
                <td>${r.boarding_point} &rarr; ${r.dropping_point}</td>
                <td>${r.schedule_time || 'Flexible'}</td>
                <td>৳${r.fare}</td>
            `;
            tbody.appendChild(tr);
        });
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
        const response = await fetch(`${API_BASE}/students/`);
        const allUsers = await response.json();
        const checkers = allUsers.filter(u => u.role === 'Checker');
        const tbody = document.querySelector('#staff-list-table tbody');
        tbody.innerHTML = '';
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
            showMessage('recharge-msg', `Success! Recharged for ${data.student_name}.`, true);
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
