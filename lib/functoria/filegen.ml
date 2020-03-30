(*
 * Copyright (c) 2013-2020 Thomas Gazagnaire <thomas@gazagnaire.org>
 * Copyright (c) 2013-2020 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c) 2015-2020 Gabriel Radanne <drupyog@zoho.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Astring
open Action.Infix

module type PROJECT = sig
  val name : string

  val version : string
end

module Make (P : PROJECT) = struct
  let lang path =
    let base, ext = Fpath.split_ext path in
    let base = Fpath.basename base in
    match (base, ext) with
    | _, (".ml" | ".mli") -> Some `OCaml
    | _, (".opam" | ".install") -> Some `Opam
    | "Makefile", _ -> Some `Make
    | ("dune" | "dune-project"), _ -> Some `Sexp
    | _ -> None

  let headers lang =
    let line = Fmt.str "Generated by %s.%s" P.name P.version in
    match lang with
    | `Sexp -> Fmt.str ";; %s" line
    | `Opam | `Make -> Fmt.str "# %s" line
    | `OCaml -> Fmt.str "(* %s *)" line

  let can_overwrite file =
    Action.is_file file >>= function
    | false -> Action.ok true
    | true -> (
        if Fpath.basename file = "dune-project" then
          Action.read_file file >|= fun x ->
          let x = String.cuts ~sep:"\n" ~empty:true x in
          match List.rev x with x :: _ -> x = headers `Sexp | _ -> false
        else
          match lang file with
          | None -> Action.ok false
          | Some lang ->
              let affix = headers lang in
              Action.read_file file >|= fun x -> String.is_infix ~affix x )

  let rm file =
    can_overwrite file >>= function
    | false -> Action.ok ()
    | true -> Action.rm file

  let with_headers file contents =
    match Fpath.basename file with
    | "dune-project" -> Fmt.str "%s\n\n%s" contents (headers `Sexp)
    | _ -> (
        match lang file with
        | None -> Fmt.invalid_arg "%a: invalide lang" Fpath.pp file
        | Some lang -> Fmt.str "%s\n\n%s" (headers lang) contents )

  let write file contents =
    can_overwrite file >>= function
    | false -> Action.ok ()
    | true -> Action.write_file file (with_headers file contents)
end
