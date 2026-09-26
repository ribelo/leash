(** Chrome DevTools Protocol framing and correlation; implemented in L2.

    L2 module: NUL-framed JSON [read]/[write], [call ?session ?deadline], and [events]
    using [Eta_rpc.Correlator], one instance per Chrome generation. No live transport
    exists in L0. *)
