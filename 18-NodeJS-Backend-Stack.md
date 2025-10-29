## Node.js Backend Stack Specification

Technical stack details for the Day Party backend API, using Node.js + Express + TypeScript.

---

### Technology Stack

#### Core
- **Runtime**: Node.js 20.x LTS (Long Term Support)
- **Language**: TypeScript 5.x (type safety, better developer experience)
- **Framework**: Express.js 4.x (minimal, flexible web framework)
- **Process Manager**: PM2 (production process management)

#### Database & ORM
- **Database**: MySQL 8+ (as per Creative Brief)
- **ORM**: Prisma (modern, type-safe ORM)
  - Alternative: Sequelize (if prefer more mature, established ORM)
  - Recommendation: **Prisma** (better TypeScript integration, modern)

#### Authentication & Security
- **JWT**: jsonwebtoken library
- **OAuth**: Passport.js with strategies:
  - `passport-google-oauth20` for Google
  - `passport-facebook` for Facebook
  - `passport-apple` for Apple (if available)
- **Password Hashing**: bcrypt (if needed for password auth later)

#### Validation & Request Parsing
- **Validation**: Zod (TypeScript-first schema validation)
  - Alternative: Joi or express-validator
- **Body Parser**: Express built-in (json, urlencoded)

#### Utilities
- **Environment Variables**: dotenv
- **HTTP Client**: axios (for external API calls)
- **Date/Time**: date-fns or day.js
- **CORS**: cors package (for API access control)

---

### Project Structure

```
backend/
├── src/
│   ├── controllers/       # Route handlers (business logic)
│   │   ├── auth.controller.ts
│   │   ├── node.controller.ts
│   │   ├── vote.controller.ts
│   │   └── notification.controller.ts
│   ├── services/          # Business logic layer
│   │   ├── auth.service.ts
│   │   ├── node.service.ts
│   │   └── vote.service.ts
│   ├── models/           # Data models (Prisma-generated)
│   ├── routes/           # Express route definitions
│   │   ├── auth.routes.ts
│   │   ├── node.routes.ts
│   │   └── vote.routes.ts
│   ├── middleware/       # Custom middleware
│   │   ├── auth.middleware.ts
│   │   ├── error.middleware.ts
│   │   └── validate.middleware.ts
│   ├── utils/            # Helper functions
│   │   ├── jwt.util.ts
│   │   └── logger.util.ts
│   ├── config/           # Configuration
│   │   ├── database.ts
│   │   ├── passport.ts
│   │   └── env.ts
│   └── app.ts            # Express app setup
├── prisma/
│   ├── schema.prisma     # Prisma schema (maps to MySQL DDL)
│   └── migrations/       # Database migrations
├── .env                  # Environment variables (gitignored)
├── .env.example          # Example env file
├── package.json
├── tsconfig.json         # TypeScript configuration
└── server.ts             # Entry point

```

---

### Dependencies

#### Production Dependencies
```json
{
  "dependencies": {
    "express": "^4.18.2",
    "prisma": "^5.7.0",
    "@prisma/client": "^5.7.0",
    "jsonwebtoken": "^9.0.2",
    "passport": "^0.6.0",
    "passport-google-oauth20": "^2.0.0",
    "passport-facebook": "^3.0.0",
    "bcrypt": "^5.1.1",
    "zod": "^3.22.4",
    "dotenv": "^16.3.1",
    "cors": "^2.8.5",
    "axios": "^1.6.2",
    "express-async-errors": "^3.1.1"
  }
}
```

#### Development Dependencies
```json
{
  "devDependencies": {
    "typescript": "^5.3.3",
    "@types/express": "^4.17.21",
    "@types/node": "^20.10.0",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/passport": "^1.0.15",
    "@types/bcrypt": "^5.0.2",
    "@types/cors": "^2.8.17",
    "ts-node": "^10.9.2",
    "ts-node-dev": "^2.0.0",
    "prisma": "^5.7.0",
    "@typescript-eslint/eslint-plugin": "^6.15.0",
    "@typescript-eslint/parser": "^6.15.0",
    "eslint": "^8.56.0"
  }
}
```

---

### Prisma Schema Example

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "mysql"
  url      = env("DATABASE_URL")
}

model User {
  id          String   @id @default(uuid())
  email       String?  @unique
  phone       String?  @unique
  displayName String   @map("display_name")
  locale      String   @default("he-IL")
  isActive    Boolean  @default(true) @map("is_active")
  role        UserRole @default(USER)
  createdAt   DateTime @default(now()) @map("created_at")
  
  nodes       Node[]
  votes       NodeVote[]
  identities  UserIdentity[]
  
  @@map("users")
}

model Node {
  id             String      @id @default(uuid())
  threadId       String      @map("thread_id")
  parentNodeId   String?     @map("parent_node_id")
  parentRelation ParentRelation? @map("parent_relation")
  title          String
  textContent    String?     @map("text_content")
  videoUrl       String?     @map("video_url")
  authorId       String?     @map("author_id")
  likeCount      Int         @default(0) @map("like_count")
  dislikeCount   Int         @default(0) @map("dislike_count")
  createdAt      DateTime    @default(now()) @map("created_at")
  
  thread         Thread      @relation(fields: [threadId], references: [id])
  author         User?       @relation(fields: [authorId], references: [id])
  votes          NodeVote[]
  children       Node[]      @relation("NodeTree")
  parent         Node?      @relation("NodeTree", fields: [parentNodeId], references: [id])
  
  @@index([threadId])
  @@index([parentNodeId])
  @@map("nodes")
}

enum UserRole {
  USER
  ADMIN
}

enum ParentRelation {
  PRO
  AGAINST
  NEUTRAL
}
```

---

### Example API Route Implementation

```typescript
// src/routes/vote.routes.ts
import { Router } from 'express';
import { authenticate } from '../middleware/auth.middleware';
import { validateRequest } from '../middleware/validate.middleware';
import { voteNodeSchema } from '../schemas/vote.schema';
import { voteController } from '../controllers/vote.controller';

const router = Router();

router.post(
  '/nodes/:nodeId/vote',
  authenticate,
  validateRequest(voteNodeSchema),
  voteController.createVote
);

router.patch(
  '/nodes/:nodeId/vote/visibility',
  authenticate,
  voteController.updateVoteVisibility
);

router.get(
  '/nodes/:nodeId/voters',
  authenticate,
  voteController.getVoters
);

export default router;
```

```typescript
// src/controllers/vote.controller.ts
import { Request, Response } from 'express';
import { voteService } from '../services/vote.service';

export const voteController = {
  async createVote(req: Request, res: Response) {
    const { nodeId } = req.params;
    const { type, isPublic } = req.body;
    const userId = req.user!.id; // From auth middleware
    
    const result = await voteService.createVote(nodeId, userId, type, isPublic);
    res.json({
      nodeId,
      tallies: result.tallies,
      myVote: result.myVote
    });
  },
  
  // ... other methods
};
```

---

### Authentication Flow (OAuth)

```typescript
// src/services/auth.service.ts
import jwt from 'jsonwebtoken';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function handleOAuthCallback(
  provider: 'google' | 'facebook' | 'apple',
  providerUserId: string,
  email: string,
  displayName: string
) {
  // Find or create user
  let user = await prisma.user.findFirst({
    where: {
      OR: [
        { email },
        {
          identities: {
            some: {
              provider,
              providerUserId
            }
          }
        }
      ]
    },
    include: { identities: true }
  });
  
  if (!user) {
    // Create new user
    user = await prisma.user.create({
      data: {
        email,
        displayName,
        identities: {
          create: {
            provider,
            providerUserId
          }
        }
      }
    });
  } else {
    // Link identity if not already linked
    const existingIdentity = user.identities.find(
      i => i.provider === provider && i.providerUserId === providerUserId
    );
    
    if (!existingIdentity) {
      await prisma.userIdentity.create({
        data: {
          userId: user.id,
          provider,
          providerUserId
        }
      });
    }
  }
  
  // Generate JWT
  const token = jwt.sign(
    { userId: user.id, role: user.role },
    process.env.JWT_SECRET!,
    { expiresIn: '1h' }
  );
  
  return { token, user };
}
```

---

### Environment Variables

```bash
# .env.example
# Database
DATABASE_URL="mysql://user:password@localhost:3306/dayparty?schema=public"

# JWT
JWT_SECRET="your-secret-key-here"
JWT_EXPIRES_IN="1h"
REFRESH_TOKEN_EXPIRES_IN="30d"

# OAuth - Google
GOOGLE_CLIENT_ID="your-google-client-id"
GOOGLE_CLIENT_SECRET="your-google-client-secret"
GOOGLE_CALLBACK_URL="http://localhost:3000/api/auth/google/callback"

# OAuth - Facebook
FACEBOOK_APP_ID="your-facebook-app-id"
FACEBOOK_APP_SECRET="your-facebook-app-secret"
FACEBOOK_CALLBACK_URL="http://localhost:3000/api/auth/facebook/callback"

# Server
PORT=3000
NODE_ENV=development

# CORS
ALLOWED_ORIGINS=http://localhost:8080,dayparty://auth/callback
```

---

### Deployment Setup (Azure VM)

#### Server Configuration
1. **Node.js Installation**:
   ```bash
   # Install Node.js 20.x LTS
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
   ```

2. **PM2 Process Manager**:
   ```bash
   npm install -g pm2
   pm2 start ecosystem.config.js
   pm2 save
   pm2 startup
   ```

3. **Nginx Reverse Proxy**:
   ```nginx
   # /etc/nginx/sites-available/dayparty-api
   server {
       listen 80;
       server_name api.dayparty.com;
       
       location / {
           proxy_pass http://localhost:3000;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection 'upgrade';
           proxy_set_header Host $host;
           proxy_cache_bypass $http_upgrade;
       }
   }
   ```

4. **SSL with Let's Encrypt**:
   ```bash
   sudo apt install certbot python3-certbot-nginx
   sudo certbot --nginx -d api.dayparty.com
   ```

#### PM2 Ecosystem Config
```javascript
// ecosystem.config.js
module.exports = {
  apps: [{
    name: 'dayparty-api',
    script: 'dist/server.js',
    instances: 1,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    },
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
};
```

---

### Development Workflow

```bash
# Install dependencies
npm install

# Set up Prisma
npx prisma generate
npx prisma migrate dev

# Development mode (with hot reload)
npm run dev

# Build for production
npm run build

# Production start
npm start
```

**package.json scripts**:
```json
{
  "scripts": {
    "dev": "ts-node-dev --respawn --transpile-only src/server.ts",
    "build": "tsc",
    "start": "node dist/server.js",
    "db:migrate": "prisma migrate dev",
    "db:generate": "prisma generate",
    "db:studio": "prisma studio"
  }
}
```

---

### Testing Strategy (Future)

- **Unit Tests**: Jest or Vitest
- **Integration Tests**: Supertest (for API endpoints)
- **E2E Tests**: (if needed)

---

### Migration from MySQL DDL to Prisma

The existing `11-MySQL-DDL.sql` can be converted to Prisma schema:
1. Prisma Introspection can read existing database
2. Or manually convert DDL to Prisma schema format
3. Generate Prisma Client for type-safe database access

---

### Benefits of Node.js + Express + TypeScript + Prisma

1. **Type Safety**: TypeScript + Prisma = end-to-end type safety
2. **Fast Development**: Quick iteration, hot reload
3. **Modern**: Latest best practices, active ecosystem
4. **Cost-Effective**: Same hosting cost as PHP (~$10/month)
5. **Developer-Friendly**: TypeScript IDE support, great tooling
6. **Scalable**: Can scale horizontally easily
7. **MySQL Support**: Prisma has excellent MySQL support

---

### Version History

- **v0.1** (2025-01-27): Initial Node.js backend stack specification
  - Technology choices (Express, TypeScript, Prisma)
  - Project structure
  - Example implementations
  - Deployment configuration

