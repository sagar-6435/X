require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const User = require('./models/User');

const users = [
  { name: 'Admin 1', email: 'admin1@gmail.com', password: 'password123' },
  { name: 'Admin 2', email: 'admin2@gmail.com', password: 'password123' },
];

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    for (const u of users) {
      const existing = await User.findOne({ email: u.email });
      if (existing) {
        console.log(`User ${u.email} already exists — skipping`);
        continue;
      }
      const hashedPassword = await bcrypt.hash(u.password, 10);
      await User.create({ name: u.name, email: u.email, password: hashedPassword });
      console.log(`Created user: ${u.email}`);
    }

    console.log('Seeding complete!');
    process.exit(0);
  } catch (err) {
    console.error('Seed error:', err.message);
    process.exit(1);
  }
}

seed();
