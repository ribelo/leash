(** Configuration schema and boot validation; implemented in L1.

    L1: [schema] is an [Eta_schema] record for Chrome paths, tab cap, expiry, and model
    keys; the Door decodes it and marks secrets/environment override. No schema exists in
    L0. *)
