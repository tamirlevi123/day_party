# Admin Panel Setup Guide

## Overview
A web-based admin panel has been created at `/admin` for managing nodes (messages/replies) in the Day Party platform.

## Access the Admin Panel

### On Local Development:
```
http://localhost:3000/admin
```

### On Production (Azure VM):
```
https://dayparty.work.gd/admin
```

## Setup Admin User

**IMPORTANT**: Your user account must have the `admin` role in the database to access the admin panel.

### Check Current Role
```sql
SELECT id, email, role FROM users WHERE email = 'tamirlevi123@gmail.com';
```

### Update to Admin Role
```sql
UPDATE users SET role = 'admin' WHERE email = 'tamirlevi123@gmail.com';
```

Or using Prisma Studio:
```powershell
cd backend ; npx prisma studio
```
Then navigate to the `users` table and change the `role` field from `user` to `admin` for your account.

## Features

The admin panel provides:

1. **Google OAuth Login** - Sign in with your Google account (tamirlevi123@gmail.com)
2. **Node Management**:
   - List all nodes (messages/replies) with filters
   - Filter by Thread ID, Author ID, Deleted status, Moderation state
   - View node details (title, content, video, metadata)
   - Edit nodes (title, content, moderation state, delete status)
   - Delete nodes (soft delete)
   - Restore deleted nodes

3. **Filters**:
   - Thread ID
   - Author ID
   - Show Deleted (All/Deleted Only/Active Only)
   - Moderation State (All/Pending/Approved/Rejected)
   - Pagination (limit/offset)

## Usage

1. Navigate to `/admin` in your browser
2. Click "Sign in with Google"
3. Authenticate with your Google account (tamirlevi123@gmail.com)
4. If you have admin role, you'll see the admin panel
5. Use filters to find nodes you want to manage
6. Click "Edit" to modify a node
7. Click "Delete" to soft-delete a node
8. Click "Restore" to restore a deleted node

## Security

- All admin endpoints require authentication (JWT token)
- All admin endpoints require `admin` role
- Non-admin users will receive 403 Forbidden error
- Tokens are stored in browser localStorage
- Logout clears the token

## Files Created

- `backend/public/admin/index.html` - Admin panel HTML
- `backend/public/admin/admin.css` - Admin panel styles
- `backend/public/admin/admin.js` - Admin panel JavaScript
- `backend/src/controllers/admin.controller.ts` - Admin API endpoints
- `backend/src/routes/admin.routes.ts` - Admin routes

## API Endpoints

All admin endpoints are prefixed with `/api/admin`:

- `GET /api/admin/nodes` - List nodes with filters
- `GET /api/admin/nodes/:nodeId` - Get single node
- `PATCH /api/admin/nodes/:nodeId` - Update node
- `DELETE /api/admin/nodes/:nodeId` - Delete node (soft delete)
- `POST /api/admin/nodes/:nodeId/restore` - Restore deleted node

## Troubleshooting

### "You do not have admin access"
- Your user role in the database must be `admin`, not `user`
- Update your role using the SQL command above

### Login fails
- Make sure Google OAuth is configured in `.env`
- Check that `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
- Verify the callback URL is configured in Google Cloud Console

### Can't see nodes
- Check that the backend is running
- Verify database connection
- Check browser console for errors

