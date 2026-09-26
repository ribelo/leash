(** Managed Chrome supervisor and browser generation; implemented in L2.

    L2 Service: [create ~sw] owns [Eta_process.Supervised] and [Child] with Chrome pipe
    fds 3/4; [status] reads live state. Deps include process manager, clock, logger. No
    child process exists in L0. *)
