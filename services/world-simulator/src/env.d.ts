/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_BASE_TOWER_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
