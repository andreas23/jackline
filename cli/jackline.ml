open Lwt
open React

let start_client cfgdir debug () =
  ignore (LTerm_inputrc.load ());
  Tls_lwt.rng_init () >>= fun () ->

  Lazy.force LTerm.stdout >>= fun term ->


  Xmpp_callbacks.load_config cfgdir >>= ( function
      | None ->
        Cli_config.configure term () >>= fun config ->
        Xmpp_callbacks.dump_config cfgdir config >|= fun () ->
        config
      | Some cfg -> return cfg ) >>= fun config ->

  Xmpp_callbacks.load_users cfgdir >>= fun (users) ->

  let history = LTerm_history.create [] in
  let user = User.find_or_add config.Config.jid users in
  let session = User.ensure_session config.Config.jid config.Config.otr_config user in
  let state = Cli_state.empty_ui_state user session users in
  let n, s_n = S.create (Unix.localtime (Unix.time ()), "nobody", "nothing") in
  Cli_client.loop debug config term history state None n s_n >>= fun state ->
  Xmpp_callbacks.dump_users cfgdir state.Cli_state.users



let config_dir = ref ""
let debug = ref false
let rest = ref []

let _ =
  let home = Unix.getenv "HOME" in
  let cfgdir = Filename.concat home ".config" in
  config_dir := Xmpp_callbacks.xmpp_config cfgdir

let usage = "usage " ^ Sys.argv.(0)

let arglist = [
  ("-f", Arg.String (fun d -> config_dir := d), "configuration directory (defaults to ~/.config/ocaml-xmpp-client/)") ;
  ("-d", Arg.Bool (fun d -> debug := d), "log to out.txt in current working directory")
]

let _ =
  try
    Arg.parse arglist (fun x -> rest := x :: !rest) usage ;
    Lwt_main.run (start_client !config_dir !debug ())
  with
  | Sys_error s -> print_endline s
