import { initializeApp, getApps } from "firebase/app";
import {
  getAuth,
  GoogleAuthProvider,
  signInWithPopup,
  signOut,
  onAuthStateChanged,
  type Auth,
} from "firebase/auth";

export interface Session {
  uid: string;
  displayName: string | null;
}
export interface AuthGateway {
  subscribe(
    listener: (user: Session | null) => void,
    onError: (error: Error) => void,
  ): () => void;
  token(force?: boolean): Promise<string>;
  signIn(): Promise<void>;
  signOut(): Promise<void>;
}
let ready: Promise<Auth> | undefined;
async function firebaseAuth() {
  ready ??= (async () => {
    const response = await fetch("/api/public/config");
    if (!response.ok)
      throw new Error(
        "Chưa kết nối cấu hình đăng nhập. Kiểm tra API và Firebase Web app.",
      );
    const data = (await response.json()) as {
      firebase: Record<string, string>;
    };
    return getAuth(getApps()[0] ?? initializeApp(data.firebase));
  })().catch((error) => {
    ready = undefined;
    throw error;
  });
  return ready;
}
export const liveAuth: AuthGateway = {
  subscribe(listener, onError) {
    let cancelled = false;
    let unsubscribe: (() => void) | undefined;
    void firebaseAuth()
      .then((auth) => {
        if (!cancelled)
          unsubscribe = onAuthStateChanged(
            auth,
            (user) =>
              listener(
                user ? { uid: user.uid, displayName: user.displayName } : null,
              ),
            onError,
          );
      })
      .catch(onError);
    return () => {
      cancelled = true;
      unsubscribe?.();
    };
  },
  async token(force = false) {
    const auth = await firebaseAuth();
    if (!auth.currentUser) throw new Error("Phiên đăng nhập đã kết thúc.");
    return auth.currentUser.getIdToken(force);
  },
  async signIn() {
    await signInWithPopup(await firebaseAuth(), new GoogleAuthProvider());
  },
  async signOut() {
    await signOut(await firebaseAuth());
  },
};
