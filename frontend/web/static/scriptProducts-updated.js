// Obtener las URLs desde las variables del template
const PRODUCTS_SERVICE_URL = '{{ products_service_url }}';
const ORDERS_SERVICE_URL = '{{ orders_service_url }}';

function getProducts() {
    fetch(`${PRODUCTS_SERVICE_URL}/api/products`, {
     method: 'GET',
     headers: {
        'Content-Type': 'application/json'
        },
     credentials: 'include'
    })
        .then(response => response.json())
        .then(data => {
            // Handle data
            console.log(data);

            // Get table body
            var productListBody = document.querySelector('#product-list tbody');
            productListBody.innerHTML = ''; // Clear previous data

            // Loop through products and populate table rows
            data.forEach(product => {
                var row = document.createElement('tr');

                // Id
                var idCell = document.createElement('td');
                idCell.textContent = product.id;
                row.appendChild(idCell);

                // Name
                var nameCell = document.createElement('td');
                nameCell.textContent = product.name;
                row.appendChild(nameCell);

                // Description
                var descCell = document.createElement('td');
                descCell.textContent = product.description;
                row.appendChild(descCell);

                // Price
                var priceCell = document.createElement('td');
                priceCell.textContent = product.price;
                row.appendChild(priceCell);

                // Stock
                var stockCell = document.createElement('td');
                stockCell.textContent = product.stock;
                row.appendChild(stockCell);

		// Order
		var orderInput = document.createElement('input');
		orderInput.type = 'text';
		orderInput.value = "0";
		row.appendChild(orderInput);

                // Actions
                var actionsCell = document.createElement('td');

                // Edit link
                var editLink = document.createElement('a');
                editLink.href = `/editProduct/${product.id}`;
                editLink.textContent = 'Edit';
                editLink.className = 'btn btn-primary mr-2';
                actionsCell.appendChild(editLink);

                // Delete link
                var deleteLink = document.createElement('a');
                deleteLink.href = '#';
                deleteLink.textContent = 'Delete';
                deleteLink.className = 'btn btn-danger';
                deleteLink.addEventListener('click', function() {
                    deleteProduct(product.id);
                });
                actionsCell.appendChild(deleteLink);

                row.appendChild(actionsCell);

                productListBody.appendChild(row);
            });
        })
        .catch(error => console.error('Error:', error));
}

function createProduct() {
    var data = {
        name: document.getElementById('name').value,
        description: document.getElementById('description').value,
        price: document.getElementById('price').value,
        stock: document.getElementById('stock').value
    };

    fetch(`${PRODUCTS_SERVICE_URL}/api/products`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    })
    .then(data => {
        // Handle success
        console.log(data);
    })
    .catch(error => {
        // Handle error
        console.error('Error:', error);
    });
}

function updateProduct() {
    var productId = document.getElementById('product-id').value;
    var data = {
        name: document.getElementById('name').value,
        description: document.getElementById('description').value,
        price: document.getElementById('price').value,
        stock: document.getElementById('stock').value
    };

    fetch(`${PRODUCTS_SERVICE_URL}/api/products/${productId}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
    })
    .then(response => {
        if (!response.ok) {
            throw new Error('Network response was not ok');
        }
        return response.json();
    })
    .then(data => {
        // Handle success
        console.log(data);
        // Optionally, redirect to another page or show a success message
    })
    .catch(error => {
        // Handle error
        console.error('Error:', error);
    });
}

function deleteProduct(productId) {
    console.log('Deleting product with ID:', productId);
    if (confirm('Are you sure you want to delete this product?')) {
        fetch(`${PRODUCTS_SERVICE_URL}/api/products/${productId}`, {
            method: 'DELETE',
        })
        .then(response => {
            if (!response.ok) {
                throw new Error('Network response was not ok');
            }
            return response.json();
        })
        .then(data => {
            // Handle success
            console.log('Product deleted successfully:', data);
            // Reload the product list
            getProducts();
        })
        .catch(error => {
            // Handle error
            console.error('Error:', error);
        });
    }
}

function orderProducts() {
  // Obtener los productos seleccionados y sus cantidades
  const selectedProducts = [];
  const productRows = document.querySelectorAll('#product-list tbody tr');
  productRows.forEach(row => {
    const quantityInput = row.querySelector('input[type="text"]');
    const quantity = parseInt(quantityInput.value);
    if (quantity > 0) {
      var productId = row.querySelector('td:nth-child(1)').textContent;
      selectedProducts.push({ id: productId, quantity });
    }
  });

  // Si no hay productos seleccionados, mostrar un mensaje de error
  if (selectedProducts.length === 0) {
    alert('Por favor, selecciona al menos un producto para realizar la orden.');
    return;
  }

  // Preparar los datos de la orden
  const orderData = {
    user: {
      name: localStorage.getItem('username'),
      email: localStorage.getItem('email')
    },
    products: selectedProducts
  };

  // Enviar los datos de la orden al endpoint usando variable
  fetch(`${ORDERS_SERVICE_URL}/api/orders`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(orderData),
    credentials: 'include'
  })
  .then(response => response.json())
  .then(data => {
    if (data.message === 'Orden creada exitosamente') {
      console.log('Orden creada exitosamente!');
      // Mostrar un mensaje de confirmación al usuario
      alert('¡Orden creada exitosamente!');
      // Actualizar la interfaz de usuario para reflejar los cambios (opcional)
    } else {
      console.error('Error al crear la orden:', data.message);
      // Mostrar un mensaje de error al usuario
      alert('Error al crear la orden. Por favor, intenta nuevamente.');
    }
  })
  .catch(error => {
    console.error('Error:', error);
    alert('Ocurrió un error al procesar la orden. Por favor, intenta nuevamente.');
  });
}