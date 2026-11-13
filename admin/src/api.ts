export type Json = Record<string, unknown>;
export class ApiFailure extends Error {
  constructor(
    public code: string,
    public status: number,
  ) {
    super(code);
  }
}
export class ApiClient {
  constructor(
    private getToken: (force?: boolean) => Promise<string>,
    private transport: typeof fetch = globalThis.fetch.bind(globalThis),
  ) {}
  async call(path: string, method = "GET", body?: unknown): Promise<Json> {
    for (let attempt = 0; attempt < 2; attempt++) {
      const token = await this.getToken(attempt > 0);
      let response: Response;
      try {
        response = await this.transport(`/api/v1${path}`, {
          method,
          headers: {
            Authorization: `Bearer ${token}`,
            ...(body === undefined
              ? {}
              : { "Content-Type": "application/json" }),
          },
          body: body === undefined ? undefined : JSON.stringify(body),
          signal: AbortSignal.timeout(25000),
        });
      } catch {
        throw new ApiFailure("network_error", 0);
      }
      if (response.status === 401 && attempt === 0) continue;
      const data = (await response.json()) as Json;
      if (!response.ok) {
        const error = data.error as { code?: string } | undefined;
        throw new ApiFailure(error?.code ?? "api_error", response.status);
      }
      return data;
    }
    throw new ApiFailure("session_expired", 401);
  }
}
export function errorText(e: unknown) {
  if (e instanceof ApiFailure)
    return (
      (
        {
          admin_required: "Tài khoản không có quyền quản trị.",
          network_error: "Không kết nối được máy chủ. Hãy thử lại.",
          google_credential_not_configured:
            "Máy chủ cần cấu hình quyền truy cập Firebase.",
          refresh_cooldown: "Vui lòng chờ một phút trước khi làm mới.",
          no_active_devices: "Người nhận chưa có thiết bị đang hoạt động.",
          invalid_input: "Thông tin chưa hợp lệ.",
          session_expired: "Phiên đăng nhập hết hạn.",
        } as Record<string, string>
      )[e.code] ?? `Yêu cầu thất bại (${e.code}).`
    );
  return e instanceof Error ? e.message : "Đã xảy ra lỗi. Hãy thử lại.";
}
export function object(value: unknown): Json {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Json)
    : {};
}
export function array(value: unknown): Json[] {
  return Array.isArray(value) ? value.map(object) : [];
}
