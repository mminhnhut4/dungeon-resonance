export class ApiError extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
export async function request(path, { token, method = 'GET', body, signal, timeout = 8000 } = {}) {
  const controller = new AbortController();
  const abort = () => controller.abort();
  signal?.addEventListener('abort', abort, { once: true });
  if (signal?.aborted) controller.abort();
  const timer = setTimeout(abort, timeout);
  try {
    const response = await fetch(`/api${path}`, {
      method, signal: controller.signal,
      headers: { ...(body ? { 'Content-Type': 'application/json' } : {}), ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      ...(body ? { body: JSON.stringify(body) } : {})
    });
    if (response.status === 204) return null;
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new ApiError(response.status, data.title || `http_${response.status}`);
    return data;
  } finally { clearTimeout(timer); signal?.removeEventListener('abort', abort); }
}
export function errorText(error) {
  if (error.name === 'AbortError') return 'Yêu cầu quá thời gian hoặc đã hủy. Tiến trình trong game được giữ nguyên.';
  const messages = {
    invalid_credentials: 'Email hoặc mật khẩu chưa đúng.', account_unavailable: 'Không tạo được tài khoản. Hãy thử đăng nhập nếu đã đăng ký.',
    password_length_12_to_128: 'Mật khẩu cần từ 12 đến 128 ký tự.', invalid_email: 'Email chưa hợp lệ.',
    service_temporarily_unavailable: 'Dịch vụ chưa sẵn sàng. Bạn có thể thử lại sau.',
  };
  return messages[error.message] || (error.status === 401 ? 'Phiên đã hết hạn. Hãy đăng nhập lại.' : 'Chưa kết nối được dịch vụ. Hãy kiểm tra mạng và thử lại.');
}
