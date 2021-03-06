open Core.Std
open Async.Std
open Sexplib
open Cufporg.Std
open Cufporg.Std.Util
let (/) = Filename.concat

module Param = struct
  open Command.Spec

  let repo_root =
    let default = "./" in
    let doc = sprintf "dir Root of repository. Default: \"%s\"." default in
    flag "-repo-root" (optional_with_default default file) ~doc

  let production =
    let default = false in
    let doc = sprintf
      " Set to true to generate file for publication. Default \
        is %b, which generates dev version of file."
      default
    in
    flag "-production" (optional_with_default default bool) ~doc

  let sort_rev =
    let default = true in
    let doc = sprintf
      " Sort results in reverse order. Default = %b."
      default
    in
    flag "-sort-rev" (optional_with_default default bool) ~doc

  let background =
    flag "-background" (required string)
      ~doc:"URL Path to background image."
end


(******************************************************************************)
(* `build` sub-command                                                        *)
(******************************************************************************)
let build_events : Command.t = Command.async
  ~summary:"build html pages for all events of given conference year"
  Command.Spec.(
    empty +>
    Param.repo_root +>
    Param.production +>
    Param.background +>
    anon ("YEAR" %: int)
  )
  (fun repo_root production background_image year () ->
     let year = Int.to_string year in

     let build_event (x:Event.t) : unit Deferred.t =
       let in_file = repo_root/"site"/year/(Event.filename_base x ^ ".md") in
       let out_file =
         repo_root/"_build"/"site"/year/(x.Event.url_title ^ ".html")
       in
       let depth = 1 in
       Util.newer in_file out_file >>= function
       | false -> (
           Log.Global.debug "%s is up to date" out_file;
           Deferred.unit
         )
       | true -> (
           Log.Global.info "converting %s → %s" in_file out_file;
           Conference.years ~repo_root () >>= fun years ->
           return (Event.to_html ~years ~background_image x) >>= fun l ->
           return @@ List.map l ~f:(Format.asprintf "%a" (Tyxml.Html.pp_elt ()))
           >>= fun x ->
           return @@ String.concat ~sep:"" x >>= fun content ->
           Mpp.main_template
             ~repo_root ~depth ~production
             ?body_class:None ~content ~out_file ()
         )
     in

     let in_dir = repo_root/"site"/year in
     Conference.of_dir in_dir >>= fun c ->
     let events =
       List.map c.Conference.sessions ~f:(fun x ->
         (x : Conference.session :> Event.t list)
       ) |>
       List.concat |>
       List.filter ~f:(fun x -> Event.(match x.typ with
         | Break | Discussion -> false
         | Talk | Keynote | Tutorial
         | BoF | Reception -> true
       ))
     in
     Deferred.List.iter events ~f:build_event
  )

let build_html : Command.t = Command.async
  ~summary:"build html page from html source"
  Command.Spec.(
    empty +>
    Param.repo_root +>
    Param.production +>
    anon ("FILE" %: file)
  )
  (fun repo_root production in_file () ->
     let depth = match Filename.parts in_file with
       | "."::"site"::parts -> List.length parts - 1
       | _ -> failwithf "%s: FILE must begin with site/" in_file ()
     in
     let in_file = repo_root/in_file in
     let out_file = repo_root/"_build"/in_file in
     Log.Global.info "converting %s → %s" in_file out_file;
     Reader.file_contents in_file >>= fun content ->
     Mpp.main_template
       ~repo_root ~depth ~production ?body_class:None ~content ~out_file ()
  )

let build_markdown : Command.t = Command.async
  ~summary:"build html page from markdown source"
  Command.Spec.(
    empty +>
    Param.repo_root +>
    Param.production +>
    anon ("FILE" %: file)
  )
  (fun repo_root production in_file () ->
     let depth = match Filename.parts in_file with
       | "."::"site"::parts -> List.length parts - 1
       | _ -> failwithf "%s: FILE must begin with site/" in_file ()
     in
     let base = String.chop_suffix_exn in_file ~suffix:".md" in
     let in_file = repo_root/in_file in
     let out_file = repo_root/"_build"/(base^".html") in
     Log.Global.info "converting %s → %s" in_file out_file;
     Reader.file_contents in_file >>= fun x ->
     return @@ Omd.of_string x >>= fun x ->
     return @@ Omd.to_html x >>= fun x ->
     Mpp.main_template
       ~repo_root ~depth ~production ?body_class:None ~content:x ~out_file ()
  )

let build_robots : Command.t = Command.async
  ~summary:"print robots.txt file to stdout"
  Command.Spec.(empty +> Param.production)
  (fun production () ->
     (
       match production with
       | true -> printf "User-agent: *\n"
       | false -> printf "User-agent: *\nDisallow: /\n"
     );
     Deferred.unit
  )

let build = Command.group
  ~summary:"build site files"
  [
    "events", build_events;
    "html", build_html;
    "markdown", build_markdown;
    "robots", build_robots;
  ]

(******************************************************************************)
(* `print` sub-command                                                        *)
(******************************************************************************)
let print_conference_list : (string * Command.t) =
  ("conference-list",
   Command.async
     ~summary:"print list of all conferences"
     Command.Spec.(
       empty
       +> Param.repo_root
       +> Param.sort_rev
       +> flag "-first" (optional int) ~doc:"N If given, years earlier \
          than this are excluded."
       +> flag "-last" (optional int) ~doc:"N If given, years later \
          than this are excluded."
     )
     (fun repo_root sort_rev first last () ->
       Conference.years ~repo_root () >>=
       lift (if sort_rev then List.rev else Fn.id) >>= fun l ->
       return (match first with
       | None -> l
       | Some first -> List.filter l ~f:(fun x -> x >= first)
       ) >>= fun l ->
       return (match last with
       | None -> l
       | Some last -> List.filter l ~f:(fun x -> x <= last)
       ) >>=
       lift (List.map ~f:(fun x ->
         sprintf "<li><a href=\"/%d/\">%d</a></li>" x x)
       ) >>=
       lift (String.concat ~sep:"\n") >>=
       lift (printf "%s\n") >>= fun () ->
       Deferred.unit
     )
  )

let print_schedule : (string * Command.t) =
  ("schedule",
   Command.async
     ~summary:"print conference schedule"
     Command.Spec.(
       empty
       +> Param.repo_root
       +> anon ("YYYY-MM-DD" %: string)
     )
     (fun repo_root date () ->
        let date = Date.of_string date in
        let year = Date.year date in
        Path.make ~repo_root (sprintf "%d" year) >>= fun dir ->
        Conference.of_dir (Path.input dir) >>= fun conf ->
        return @@ Conference.schedule conf date >>= fun x ->
        return @@ Format.asprintf "%a" (Tyxml.Html.pp_elt ()) x >>= fun x ->
        return @@ print_endline x
     )
  )

let print_menu : (string * Command.t) =
  ("menu",
   Command.async
     ~summary:"print menu"
     Command.Spec.(
       empty +>
       Command.Spec.(
         flag "-main-year" (optional int)
           ~doc:"INT Year to display as visible item of menu."
       ) +>
       Param.repo_root
     )
     (fun main_year repo_root () ->
        Conference.years ~repo_root () >>= fun years ->
        return @@ Html.menu ?main_year ~years >>= fun x ->
        return @@ Format.asprintf "%a" (Tyxml.Html.pp_elt ()) x >>= fun x ->
        return @@ print_endline x
     )
  )

let print : (string * Command.t) =
  ("print",
   Command.group ~summary:"print various items"
     [
       print_schedule;
       print_conference_list;
       print_menu;
     ]
  )


(******************************************************************************)
(* `main` command                                                             *)
(******************************************************************************)
let main = Command.group
  ~summary:"build and publish the cufp.org website"
  ["build",build; print]

;;
let build_info = match About.git_commit with
  | None -> "unknown"
  | Some x -> x
in
try Command.run ~build_info main
with e -> eprintf "%s\n" (Exn.to_string e)
