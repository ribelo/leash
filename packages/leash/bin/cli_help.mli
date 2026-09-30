val all_exits : Cmdliner.Cmd.Exit.info list
val command_info : string -> doc:string -> examples:string list -> Cmdliner.Cmd.info
val local_info : string -> doc:string -> examples:string list -> Cmdliner.Cmd.info
val top_man : Cmdliner.Manpage.block list
