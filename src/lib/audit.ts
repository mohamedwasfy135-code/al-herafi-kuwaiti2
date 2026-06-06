import { db } from '@/lib/db'

export type AuditAction = 'CREATE' | 'UPDATE' | 'DELETE' | 'PAY' | 'MERGE' | 'EXPORT' | 'IMPORT'

export async function logAudit({
  businessId,
  userId,
  action,
  entity,
  entityId,
  changes,
  ipAddress,
}: {
  businessId: string
  userId?: string
  action: AuditAction
  entity: string
  entityId?: number
  changes?: { before?: unknown; after?: unknown }
  ipAddress?: string
}) {
  try {
    await db.auditLog.create({
      data: {
        businessId,
        userId,
        action,
        entity,
        entityId,
        changes: changes ? JSON.parse(JSON.stringify(changes)) : undefined,
        ipAddress,
      },
    })
  } catch (error) {
    console.error('[AUDIT] Failed to log:', error)
  }
}
