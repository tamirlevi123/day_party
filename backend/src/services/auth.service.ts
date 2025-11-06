import { PrismaClient, Provider, Role } from '@prisma/client';
import { generateAccessToken, generateRefreshToken, JWTPayload } from '../utils/jwt.util';
import { prisma } from '../server';

export interface OAuthUserInfo {
  provider: Provider;
  providerUserId: string;
  email: string | null;
  displayName: string;
}

/**
 * Find or create user from OAuth information
 */
export async function findOrCreateUserFromOAuth(oauthInfo: OAuthUserInfo): Promise<{
  user: { id: string; displayName: string; role: Role };
  isNewUser: boolean;
}> {
  // First, try to find existing identity
  let identity = await prisma.userIdentity.findUnique({
    where: {
      provider_providerUserId: {
        provider: oauthInfo.provider,
        providerUserId: oauthInfo.providerUserId,
      },
    },
    include: {
      user: true,
    },
  });

  // If identity exists, return the user
  if (identity) {
    return {
      user: {
        id: identity.user.id,
        displayName: identity.user.displayName,
        role: identity.user.role,
      },
      isNewUser: false,
    };
  }

  // If identity doesn't exist, check if user exists by email
  let user = null;
  if (oauthInfo.email) {
    user = await prisma.user.findUnique({
      where: { email: oauthInfo.email },
    });
  }

  // If user exists, link the identity
  if (user) {
    await prisma.userIdentity.create({
      data: {
        userId: user.id,
        provider: oauthInfo.provider,
        providerUserId: oauthInfo.providerUserId,
        email: oauthInfo.email,
        displayName: oauthInfo.displayName,
      },
    });

    return {
      user: {
        id: user.id,
        displayName: user.displayName,
        role: user.role,
      },
      isNewUser: false,
    };
  }

  // Create new user and identity
  const newUser = await prisma.user.create({
    data: {
      email: oauthInfo.email,
      displayName: oauthInfo.displayName,
      locale: 'he-IL',
      isActive: true,
      role: 'user' as Role,
      identities: {
        create: {
          provider: oauthInfo.provider,
          providerUserId: oauthInfo.providerUserId,
          email: oauthInfo.email,
          displayName: oauthInfo.displayName,
        },
      },
    },
  });

  return {
    user: {
      id: newUser.id,
      displayName: newUser.displayName,
      role: newUser.role,
    },
    isNewUser: true,
  };
}

/**
 * Generate tokens for user
 */
export function generateTokensForUser(userId: string, role: Role): {
  token: string;
  refreshToken: string;
} {
  const payload: JWTPayload = {
    userId,
    role,
  };

  return {
    token: generateAccessToken(payload),
    refreshToken: generateRefreshToken(payload),
  };
}

/**
 * Logout user (invalidate refresh token if needed)
 * For now, we just return success - token invalidation can be added later
 */
export async function logoutUser(userId: string): Promise<void> {
  // Future: Could add refresh token blacklist here
  // For now, JWT tokens are stateless and will expire naturally
  return Promise.resolve();
}

