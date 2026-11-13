import { z } from "zod";
const id = z.string().regex(/^[a-zA-Z0-9_.-]{1,160}$/);
const day = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/)
  .refine((v) => {
    const d = new Date(`${v}T00:00:00Z`);
    return !Number.isNaN(d.valueOf()) && d.toISOString().slice(0, 10) === v;
  });
export const meal = z
  .object({
    date: day,
    type: z.enum(["breakfast", "lunch", "dinner", "snack"]),
    description: z.string().trim().min(1).max(120),
  })
  .strict();
export const profile = z
  .object({
    displayName: z.string().trim().max(80),
    timezone: z.string().max(60).default("Asia/Bangkok"),
  })
  .strict();
export const goals = z
  .object({
    goals: z
      .array(z.enum(["logMeals", "planMeals", "learn"]))
      .min(1)
      .max(3),
  })
  .strict();
export const plan = z
  .object({
    date: day,
    slot: z.enum(["breakfast", "lunch", "dinner"]),
    recipeId: z.enum(["rice-veg-beans", "toast-egg", "meal-prep-box"]),
  })
  .strict();
export const operation = z
  .object({
    opId: id,
    kind: z.enum(["profile", "goals", "meal", "plan"]),
    id,
    baseVersion: z.number().int().min(0),
    deleted: z.boolean().default(false),
    data: z.unknown(),
  })
  .strict();
export type Operation = z.infer<typeof operation>;
export const push = z
  .object({ operations: z.array(operation).min(1).max(5) })
  .strict();
export const device = z
  .object({
    installationId: id,
    installationSecret: z.string().min(32).max(100),
    token: z.string().min(20).max(4096),
    generation: z.number().int().min(1).max(Number.MAX_SAFE_INTEGER),
    platform: z.enum(["android", "ios"]),
    appVersion: z.string().max(40),
  })
  .strict();
export const unregister = z
  .object({
    installationId: id,
    installationSecret: z.string().min(32).max(100),
    generation: z.number().int().min(1),
  })
  .strict();
export const sign = z
  .object({
    kind: z.enum(["photo", "pdf"]),
    mealId: id.optional(),
    mealVersion: z.number().int().positive().optional(),
    contentHash: z.string().regex(/^[a-f0-9]{64}$/),
    fileName: z.string().max(100).optional(),
  })
  .strict();
export const complete = z
  .object({
    publicId: z.string().max(300),
    version: z.string().regex(/^\d{1,20}$/),
    signature: z.string().regex(/^[a-f0-9]{40}$/),
  })
  .strict();
export const campaign = z
  .object({
    targetUid: id,
    requestKey: id,
    title: z.string().trim().min(1).max(100),
    body: z.string().trim().min(1).max(500),
    route: z
      .string()
      .max(120)
      .refine(
        (v) =>
          /^\/(home|log|plan|library|notifications)$/.test(v) ||
          /^\/library\/[a-z0-9-]+$/.test(v) ||
          /^\/plan\/recipe\/[a-z0-9-]+$/.test(v),
      ),
  })
  .strict();
export function parseData(op: Operation): unknown {
  if (op.deleted) return {};
  const schemas = { meal, profile, goals, plan };
  return schemas[op.kind].parse(op.data);
}
