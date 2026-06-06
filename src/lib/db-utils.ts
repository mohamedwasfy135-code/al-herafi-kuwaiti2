import { db } from '@/lib/db'

/**
 * Resolves a businessId that might be a user ID (ownerId) to the actual Business.id
 * This handles backward compatibility where some clients may send userId instead of businessId
 */
export async function resolveBusinessId(id: string): Promise<string | null> {
  if (!id) return null

  // First try as a direct business ID
  const directBusiness = await db.business.findUnique({ where: { id }, select: { id: true } })
  if (directBusiness) return directBusiness.id

  // Then try as owner ID
  const byOwner = await db.business.findFirst({ where: { ownerId: id }, select: { id: true } })
  if (byOwner) return byOwner.id

  return null
}
