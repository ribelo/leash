(** Tab lifecycle, ownership and expiry; implemented in L3 and later rows.

    L3 Service: [create ~sw] owns tabs, per-tab locks, [Eta.Retry.repeat] expiry and
    Chrome generation subscription; [status] reports live state. No registry exists in L0.
*)
