function postNUI(callbackName, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${callbackName}`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(data)
    });
}

function startRP(id) {
    postNUI('startRP', {rpID: id});
}

function endRP(id) {
    postNUI('endRP', {rpID: id});
}

function closeUI() {
    postNUI('close', {});
}

// The event listener for messages from the client script
window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === "show") {
        document.getElementById('main-content').style.display = 'none';
        document.getElementById('no-permission').style.display = 'none';
        // UI shown, waiting for data
    } else if (data.action === "noPermission") {
        document.getElementById('main-content').style.display = 'none';
        document.getElementById('no-permission').style.display = 'block';
    } else if (data.action === "update") {
        updateTables(data.queue, data.active);
        document.getElementById('main-content').style.display = 'block';
    }
});

function updateTables(queue, active) {
    const queueTableBody = document.querySelector("#queue-table tbody");
    const activeTableBody = document.querySelector("#active-table tbody");

    queueTableBody.innerHTML = "";
    activeTableBody.innerHTML = "";

    // Update queue
    queue.forEach(rp => {
        let row = document.createElement('tr');
        row.innerHTML = `
            <td>${rp.id}</td>
            <td>${rp.title}</td>
            <td>${rp.region}</td>
            <td>${rp.participants.length}</td>
            <td><button onclick="startRP(${rp.id})">Start</button></td>
        `;
        queueTableBody.appendChild(row);
    });

    // Update active
    active.forEach(rp => {
        let row = document.createElement('tr');
        row.innerHTML = `
            <td>${rp.id}</td>
            <td>${rp.title}</td>
            <td>${rp.region}</td>
            <td>${rp.participants.length}</td>
            <td><button onclick="endRP(${rp.id})">End</button></td>
        `;
        activeTableBody.appendChild(row);
    });
}
