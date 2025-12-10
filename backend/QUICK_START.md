# Backend Quick Start Guide

## Starting the Backend Server

### Step 1: Check Environment Variables

Make sure you have a `.env` file in the `backend` directory. If not, copy from `env.example`:

```bash
cd backend
copy env.example .env
```

Then edit `.env` with your database credentials and settings.

### Step 2: Install Dependencies (if needed)

```bash
npm install
```

### Step 3: Generate Prisma Client

```bash
npm run db:generate
```

### Step 4: Start the Development Server

```bash
npm run dev
```

This will:
- Start the server on `http://localhost:3000`
- Enable hot reload (auto-restarts on file changes)
- Show logs in the terminal

### Step 5: Verify It's Running

Open in browser: `http://localhost:3000/health`

You should see: `{"status":"OK","timestamp":"..."}`

---

## Common Issues

### "Cannot connect to database"
- Make sure MySQL is running
- Check `.env` has correct `DATABASE_URL`
- Verify database exists: `mysql -u dayparty -p dayparty`

### "Port 3000 already in use"
- Stop other processes using port 3000
- Or change `PORT` in `.env` file

### "Prisma Client not generated"
- Run: `npm run db:generate`

---

## Development Commands

- `npm run dev` - Start development server (with hot reload)
- `npm start` - Start production server (requires build first)
- `npm run build` - Build TypeScript to JavaScript
- `npm run db:generate` - Generate Prisma client
- `npm run db:push` - Push schema changes to database
- `npm run db:migrate` - Run database migrations
- `npm run db:studio` - Open Prisma Studio (database GUI)

