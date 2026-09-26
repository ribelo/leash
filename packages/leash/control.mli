(** Private control socket listener; implemented in L3.

    L3 Service: [create ~sw] runs [Eta_ipc.Listener] with schema codecs and command
    budgets, dispatching to Tabs; [status] reports live state. No socket exists in L0. *)
