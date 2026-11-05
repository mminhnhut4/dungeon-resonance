import React, { useRef, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { request, errorText } from './api';
import './style.css';

const realms = ['Luyện Khí I', 'Luyện Khí II', 'Luyện Khí III', 'Trúc Cơ sơ kỳ'];
const number = value => new Intl.NumberFormat('vi-VN').format(value || 0);
function Portal() {
  const [user, setUser] = useState(null), [token, setToken] = useState(null), [snapshot, setSnapshot] = useState(null);
  const [email, setEmail] = useState(''), [password, setPassword] = useState('');
  const [mode, setMode] = useState('login'), [busy, setBusy] = useState(false), [notice, setNotice] = useState(''), [empty, setEmpty] = useState(false);
  const generation = useRef(0), pending = useRef(null), inFlight = useRef(false);
  async function action(work) {
    if (inFlight.current) return;
    inFlight.current = true; setBusy(true); setNotice('');
    const current = ++generation.current, controller = new AbortController(); pending.current = controller;
    try { await work(controller.signal, () => current === generation.current); }
    catch (error) { if (current === generation.current) { setNotice(errorText(error)); if (error.status === 401) { setToken(null); setUser(null); setSnapshot(null); } } }
    finally { if (current === generation.current) { setBusy(false); inFlight.current = false; pending.current = null; } }
  }
  async function read(accessToken, signal, valid) {
    try { const result = await request('/progress', { token: accessToken, signal }); if (valid()) { setSnapshot(result); setEmpty(false); } }
    catch (error) { if (error.status === 404) { if (valid()) { setEmpty(true); setSnapshot(null); } } else throw error; }
  }
  function submit(event) {
    event.preventDefault();
    action(async (signal, valid) => {
      if (mode === 'register') await request('/auth/register', { method: 'POST', body: { email, password }, signal });
      const login = await request('/auth/login', { method: 'POST', body: { email, password }, signal });
      if (!valid()) return;
      setToken(login.accessToken); setUser(login.user); setPassword('');
      await read(login.accessToken, signal, valid);
    });
  }
  async function logout() {
    const prior = token;
    generation.current++; pending.current?.abort(); inFlight.current = false;
    setToken(null); setUser(null); setSnapshot(null); setPassword(''); setNotice(''); setBusy(false); setEmpty(false);
    try { await request('/auth/logout', { method: 'POST', token: prior }); } catch { /* Local token is gone even if network is unavailable. */ }
  }
  return <div className="app">
    <header><a className="brand" href="/" aria-label="Dungeon Resonance"><span className="seal">符</span><span>DUNGEON<br/><b>RESONANCE</b></span></a><span className="edition">AMD201 · NHÓM 3</span></header>
    <main>
      <section className="intro"><p className="eyebrow">HÀNH TRÌNH CỦA BẠN</p><h1>Giữ lửa.<br/>Tiếp bước.</h1><p>Tiến trình từ Godot và cổng thông tin dùng chung một tài khoản. Chỉ bạn xem được bản lưu của mình.</p><div className="rule"/><small>Chơi trong game · Đồng bộ tại căn cứ · Xem lại tại đây</small></section>
      {!user ? <section className="panel auth"><div className="section-line">01 / TÀI KHOẢN</div><h2>{mode === 'login' ? 'Trở lại hành trình' : 'Bắt đầu hành trình'}</h2><p className="muted">Đăng nhập bằng tài khoản dùng trong game.</p>
        <form onSubmit={submit}><label>Email<input type="email" autoComplete="username" value={email} onChange={e => setEmail(e.target.value)} required maxLength={254}/></label><label>Mật khẩu<input type="password" autoComplete={mode === 'login' ? 'current-password' : 'new-password'} value={password} onChange={e => setPassword(e.target.value)} required minLength={12} maxLength={128}/></label><button disabled={busy} className="primary">{busy ? 'Đang kết nối…' : mode === 'login' ? 'Đăng nhập →' : 'Tạo tài khoản →'}</button></form>
        <button className="text-button" disabled={busy} onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setNotice(''); }}>{mode === 'login' ? 'Chưa có tài khoản? Đăng ký' : 'Đã có tài khoản? Đăng nhập'}</button>
        <p className="privacy">Mật khẩu không lưu trong trình duyệt. Tải lại trang sẽ cần đăng nhập lại.</p>
      </section> : <section className="dashboard"><div className="account"><div><span className="section-line">02 / BẢN LƯU CỦA BẠN</span><h2>{user.email}</h2></div><button onClick={logout}>Đăng xuất</button></div>
        <div className="toolbar"><span className="status"><i/> {busy ? 'Đang cập nhật' : 'Tài khoản đã xác thực'}</span><button disabled={busy} onClick={() => action((signal, valid) => read(token, signal, valid))}>Làm mới</button></div>
        {empty && <div className="panel empty"><div className="empty-symbol">◇</div><h3>Chưa có bản lưu cloud</h3><p>Mở game, trở về căn cứ và chọn <b>Lưu cloud</b>. Tiến trình local vẫn được giữ riêng.</p></div>}
        {snapshot && <><div className="stats"><article><span>TẦNG ĐÃ GHI NHẬN</span><strong>{snapshot.summary.clearedFloor || '—'}</strong><small>Trong tiến trình đã đồng bộ</small></article><article><span>CẢNH GIỚI</span><strong className="realm">{realms[snapshot.summary.realm] || 'Chưa xác định'}</strong><small>Giữ đúng mốc trong game</small></article><article><span>TÀN HỒN</span><strong>{number(snapshot.summary.souls)}</strong><small>Linh thạch: {number(snapshot.summary.coins)}</small></article></div>
          <div className="panel details"><div className="section-line">BẢN LƯU ĐÃ NHẬN</div><h3>Phiên bản #{snapshot.revision}</h3><dl><div><dt>Lần đồng bộ</dt><dd>{new Date(snapshot.updatedAt).toLocaleString('vi-VN')}</dd></div><div><dt>Trang bị / vật phẩm</dt><dd>{number(snapshot.summary.items)} mục</dd></div><div><dt>Profile / trạng thái NPC</dt><dd>{Object.keys(snapshot.capsule.files).length} tệp được giữ cùng nhau</dd></div></dl><p className="muted">Trang này chỉ xem tiến trình. Khi có bản lưu mới hơn, game sẽ yêu cầu bạn chọn tải trước khi ghi tiếp.</p></div></>}
      </section>}
      {notice && <div className="notice" role="alert">{notice}</div>}
    </main><footer><span>Nhựt · Khánh · Nam</span><span>Dungeon Resonance · AMD201</span></footer>
  </div>;
}
createRoot(document.getElementById('root')).render(<Portal/>);
