// Obtener las URLs desde las variables del template
const ORDERS_SERVICE_URL = '{{ orders_service_url }}';

function getOrders() {
  fetch(`${ORDERS_SERVICE_URL}/api/orders`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json'
    },
    credentials: 'include'
  })
    .then(response => response.json())
    .then(data => {
      var tbody = document.querySelector('#order-list tbody');
      tbody.innerHTML = '';
      data.forEach(order => {
        var row = document.createElement('tr');

        var idCell = document.createElement('td');
        idCell.textContent = order.id;
        row.appendChild(idCell);

        var userNameCell = document.createElement('td');
        userNameCell.textContent = order.userName;
        row.appendChild(userNameCell);

        var userEmailCell = document.createElement('td');
        userEmailCell.textContent = order.userEmail;
        row.appendChild(userEmailCell);

        var totalCell = document.createElement('td');
        totalCell.textContent = order.saleTotal;
        row.appendChild(totalCell);

        var dateCell = document.createElement('td');
        dateCell.textContent = order.date || '';
        row.appendChild(dateCell);

        var actionsCell = document.createElement('td');
        var editLink = document.createElement('a');
        editLink.href = `/editOrder/${order.id}`;
        editLink.textContent = 'View';
        editLink.className = 'btn btn-primary mr-2';
        actionsCell.appendChild(editLink);
        row.appendChild(actionsCell);

        tbody.appendChild(row);
      });
    })
    .catch(error => console.error('Error:', error));
}

function addProductRow() {
  var tbody = document.querySelector('#products-table tbody');
  var row = document.createElement('tr');

  var idCell = document.createElement('td');
  var idInput = document.createElement('input');
  idInput.type = 'text';
  idInput.className = 'form-control';
  idCell.appendChild(idInput);
  row.appendChild(idCell);

  var qtyCell = document.createElement('td');
  var qtyInput = document.createElement('input');
  qtyInput.type = 'number';
  qtyInput.min = '1';
  qtyInput.value = '1';
  qtyInput.className = 'form-control';
  qtyCell.appendChild(qtyInput);
  row.appendChild(qtyCell);

  var actionCell = document.createElement('td');
  var delBtn = document.createElement('button');
  delBtn.type = 'button';
  delBtn.className = 'btn btn-danger';
  delBtn.textContent = 'Remove';
  delBtn.addEventListener('click', function () {
    row.remove();
  });
  actionCell.appendChild(delBtn);
  row.appendChild(actionCell);

  tbody.appendChild(row);
}

function createOrder() {
  var userName = document.getElementById('userName').value.trim();
  var userEmail = document.getElementById('userEmail').value.trim();
  var products = [];

  var rows = document.querySelectorAll('#products-table tbody tr');
  rows.forEach(r => {
    var id = r.querySelector('td:nth-child(1) input').value.trim();
    var qty = Number(r.querySelector('td:nth-child(2) input').value || '0');
    if (id && !isNaN(qty) && qty > 0) {
      products.push({ id: Number(id), quantity: qty });
    }
  });

  // Validación antes de enviar
  if (!userName || !userEmail) {
    alert('Por favor, ingresa nombre y correo de usuario.');
    return;
  }
  if (products.length === 0) {
    alert('Agrega al menos un producto con cantidad válida.');
    return;
  }

  const orderData = {
    user: { name: userName, email: userEmail },
    products: products
  };
  console.log('Datos enviados a /api/orders:', orderData);

  fetch(`${ORDERS_SERVICE_URL}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    credentials: 'include',
    body: JSON.stringify(orderData)
  })
    .then(r => {
      if (!r.ok) throw new Error('Request failed');
      return r.json();
    })
    .then(d => {
      alert(d.message || 'Orden creada');
      getOrders();
    })
    .catch(e => alert('Error: ' + e.message));
}