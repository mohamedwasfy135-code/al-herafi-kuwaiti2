import { db } from '@/lib/db'

// UUID validation regex
const UUID_REGEX = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

/**
 * Validates if a string is a valid UUID
 */
export function isValidUUID(str: string): boolean {
  return UUID_REGEX.test(str)
}

/**
 * Resolves a businessId parameter:
 * - If valid UUID, returns it as-is
 * - If invalid (like "demo"), returns the first active business ID
 * - If no businesses exist, returns empty string
 */
export async function resolveBusinessId(businessId: string): Promise<string> {
  if (businessId && isValidUUID(businessId)) {
    return businessId
  }

  // Fallback: get first active business
  const firstBusiness = await db.business.findFirst({
    where: { isActive: true },
    select: { id: true },
  })

  return firstBusiness?.id || ''
}
