// path "kv/*" {
//   capabilities = ["read"]
// }

path "kv/data" {
  capabilities = ["read"]
}

path "kv/metadata" {
  capabilities = ["read"]
}
