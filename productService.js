const express = require('express');
const mysql = require('mysql2');

// Create a connection to the database
const db = mysql.createConnection({
  host: '192.168.29.62',
  user: 'vm1', 
  password: 'vm1',       
  database: 'productdb', 
});

// Connect to the database
db.connect((err) => {
  if (err) {
    console.error('Error connecting to the database:', err.stack);
    return;
  }
  console.log('Connected to the database');
});

const app = express();
const port = 3000;

app.use(express.json());

// Create a new product
app.post('/products', (req, res) => {
  const { name, description, price, stock } = req.body;

  // Insert product data into the database
  db.query(
    'INSERT INTO products (name, description, price, stock) VALUES (?, ?, ?, ?)',
    [name, description, price, stock],
    (err, results) => {
      if (err) {
        console.error('Error inserting product:', err);
        return res.status(500).send('Error inserting product');
      }
      res.status(201).json({ id: results.insertId, name, description, price, stock });
    }
  );
});

// Get all products
app.get('/products', (req, res) => {
  db.query('SELECT * FROM products', (err, results) => {
    if (err) {
      console.error('Error fetching products:', err);
      return res.status(500).send('Error fetching products');
    }
    res.json(results);
  });
});

// Get a product by ID
app.get('/products/:id', (req, res) => {
  const { id } = req.params;
  db.query('SELECT * FROM products WHERE id = ?', [id], (err, results) => {
    if (err) {
      console.error('Error fetching product:', err);
      return res.status(500).send('Error fetching product');
    }
    if (results.length === 0) {
      return res.status(404).send('Product not found');
    }
    res.json(results[0]);
  });
});

// Update a product by ID
app.put('/products/:id', (req, res) => {
  const { id } = req.params;
  const { name, description, price, stock } = req.body;

  db.query(
    'UPDATE products SET name = ?, description = ?, price = ?, stock = ? WHERE id = ?',
    [name, description, price, stock, id],
    (err, results) => {
      if (err) {
        console.error('Error updating product:', err);
        return res.status(500).send('Error updating product');
      }
      if (results.affectedRows === 0) {
        return res.status(404).send('Product not found');
      }
      res.send('Product updated');
    }
  );
});

// Delete a product by ID
app.delete('/products/:id', (req, res) => {
  const { id } = req.params;
  db.query('DELETE FROM products WHERE id = ?', [id], (err, results) => {
    if (err) {
      console.error('Error deleting product:', err);
      return res.status(500).send('Error deleting product');
    }
    if (results.affectedRows === 0) {
      return res.status(404).send('Product not found');
    }
    res.send('Product deleted');
  });
});

// Start the server
app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
});
