module Result = Common.Result
module Option = Common.Option
module Card = Query.Card
module Type = Query.Type
module Const = Query.Const

let liftResult = function
  | Result.Ok v -> Run.return v
  | Result.Error err -> Run.error (`DatabaseError err)

let executionError err = Run.error (`DatabaseError err)

type t = {
  value : Value.t;
  univ : Universe.t;
}

type error = [ `DatabaseError of string | `QueryTypeError of string ]
type ('v, 'err) comp = ('v, [> error ] as 'err) Run.t

type entityRef = {
  refEntityName : string;
  refEntityId : string;
}

let univ {univ;_} = univ

let root {value;_} = value

let ofJson ~univ value =
  let value = value |> Value.ofJson in
  {univ; value}

let ofStringExn ~univ value =
  let value = value |> Js.Json.parseExn |> Value.ofJson in
  {univ; value}

let parseRefOpt value =
  let open Common.Option.Syntax in
  match Value.classify value with
  | Value.Object dict ->
    let%bind ref = Js.Dict.get dict "$ref" in
    let%bind ref = Value.decodeObj ref in
    let%bind refEntityName = Js.Dict.get ref "entity" in
    let%bind refEntityName = Value.decodeString refEntityName in
    let%bind refEntityId = Js.Dict.get ref "id" in
    let%bind refEntityId = Value.decodeString refEntityId in
    return {refEntityName; refEntityId}
  | _ -> None

(*
 * Format value by removing all not explicitly mentioned references according to
 * the type info and query result.
 *)
let formatValue ~ctyp value =

  let open Run.Syntax in

  let rec filterOutRefsAndRecurse ~fields input =
    let%bind obj =
      let f output {Type. fieldName; fieldCtyp} =
        match fieldCtyp with
        | _, Type.Entity _ -> return output
        | _, _ ->
          begin match Js.Dict.get input fieldName with
          | Some value ->
            let%bind value = format ~ctyp:fieldCtyp value in
            Js.Dict.set output fieldName value;
            return output
          | None -> return output
          end
      in
      Run.List.foldLeft ~f ~init:(Js.Dict.empty ()) fields
    in
    return (Value.obj obj)

  and recurse ~fields input =
    let%bind obj =
      let f output {Type. fieldName; fieldCtyp} =
        match Js.Dict.get input fieldName with
        | Some value ->
          let%bind value = format ~ctyp:fieldCtyp value in
          Js.Dict.set output fieldName value;
          return output
        | None -> return output
      in
      Run.List.foldLeft ~f ~init:(Js.Dict.empty ()) fields
    in
    return (Value.obj obj)

  and recurseIntoArrayWith ~recurse ~fields items =
    let f value =
      match Value.classify value with
      | Value.Object obj -> recurse ~fields obj
      | _ -> return value
    in
    let%bind items = Run.Array.map ~f items in
    return (Value.array items)

  and format ~ctyp value =
    match ctyp, Value.classify value with
    | (Card.One, (Type.Entity {entityFields; _} as typ)), Value.Object value
    | (Card.Opt, (Type.Entity {entityFields; _} as typ)), Value.Object value ->
      filterOutRefsAndRecurse ~fields:(entityFields typ) value
    | (Card.Many, (Type.Entity {entityFields; _} as typ)), Value.Array items ->
      recurseIntoArrayWith ~recurse:filterOutRefsAndRecurse ~fields:(entityFields typ) items

    | (Card.One, Type.Record fields), Value.Object obj
    | (Card.Opt, Type.Record fields), Value.Object obj ->
      recurse ~fields obj
    | (Card.Many, Type.Record fields), Value.Array items ->
      recurseIntoArrayWith ~recurse ~fields items
    | _ -> return value
  in

  format ~ctyp value

let execute ?value ~db query =
  let open Run.Syntax in

  let isRoot value = value == db.value in

  let rec navigate name value =
    match Value.classify value with
    | Value.Object obj ->
      begin match Js.Dict.get obj name with
      | Some value ->
        let%bind value = expandRef value in
        return value
      | None ->
        let msg = {j|no such key "$name"|j} in
        Js.log3 "ERROR:" msg [%bs.obj { data = value; key = name; }];
        executionError msg
      end
    | Value.Null -> return Value.null
    | _ -> executionError "cannot traverse this"

  and navigateFromRoot name value =
    let%bind value = navigate name value in
    match Value.classify value with
    | Value.Object value ->
      let value = Js.Dict.values value in
      return (Value.array value)
    | _ -> executionError "invalid db structure: expected an entity collection"

  and aux ~(value : Value.t) ((_bindings, (_card, typ)), syn) =

    match typ, syn with
    | Type.Void, Query.Typed.Void ->
      return db.value
    | _, Query.Typed.Void ->
      executionError "invalid type for void"

    | _, Query.Typed.Here ->
      return value

    | _, Query.Typed.Name (_name, query) ->
      aux ~value query

    | _, Query.Typed.Where (parent, _bindings) ->
      aux ~value parent

    | Type.Value Type.String, Query.Typed.Const (Const.String v) ->
      return (Value.string v)
    | Type.Value Type.Number, Query.Typed.Const (Const.Number v) ->
      return (Value.number v)
    | Type.Value Type.Bool, Query.Typed.Const (Const.Bool v) ->
      return (Value.bool v)
    | Type.Value Type.Null, Query.Typed.Const (Const.Null) ->
      return (Value.null)
    | _, Query.Typed.Const _ ->
      executionError "invalid type for const"

    | Type.Value Type.Number, Query.Typed.Count query ->
      let%bind value = aux ~value query in
      begin match Value.classify value with
      | Value.Null -> return (Value.number 0.)
      | Value.Array items -> return (Value.number (float_of_int (Array.length items)))
      | _ -> return (Value.number 1.)
      end
    | _, Query.Typed.Count _ ->
      executionError "invalid type for count"

    | _, Query.Typed.First query ->
      let%bind value = aux ~value query in
      begin match Value.classify value with
      | Value.Array items ->
        if Array.length items > 0
        then return (Array.get items 0)
        else return Value.null
      | _ -> return value
      end

    | Type.Screen _ as typ, Query.Typed.Screen (query, { screenName; screenArgs; }) ->

      let make value =
        match Value.classify value with
        | Value.Null -> return Value.null
        | _ ->
          let univ = univ db in
          let%bind screen = liftResult (Universe.lookupScreenResult screenName univ) in
          let ui =
            Value.UI.make
              ~univ
              ~screen
              ~name:screenName
              ~args:screenArgs
              ~typ
              ~value
              ~parentQuery:query
          in
          return (Value.ui ui)
      in

      (* If package expects cardinality One we do a prefetch, ideally we
        * should prefetch just exists(query) instead of query itself so we
        * can minimize the work for db to do.
        *)
      let%bind prefetch = aux ~value query in
      begin match Value.classify prefetch with
      | Value.Null -> return Value.null
      | _ -> make value
      end
    | _, Query.Typed.Screen _ ->
      executionError "invalid type for screen"

    | _, Query.Typed.Navigate (query, { navName; }) ->
      let%bind value = aux ~value query in
      let%bind value = expandRef value in

      begin match isRoot value, Value.classify value with

      | true, Value.Object _ ->
        navigateFromRoot navName value
      | true, _ ->
        executionError "invalid db structure: expected an object as the root"

      | _, Value.Object _ -> navigate navName value
      | _, Value.Array items  ->
        let%bind items = Run.Array.map ~f:(navigate navName) items in
        let items =
          let f res item =
            match Value.classify item with
            | Value.Array item -> Belt.Array.concat res item
            | _ -> ignore (Js.Array.push item res); res
          in
          Belt.Array.reduce items (Belt.Array.makeUninitializedUnsafe 0) f in
        return (Value.array items)
      | _, Value.Null ->
        return Value.null
      | _, Value.UI ui ->
        let%bind outQuery = Value.UI.outQuery ui in
        let queryValue = Value.UI.value ui in
        let%bind value = aux ~value:queryValue outQuery in
        navigate navName value
      | _ -> executionError {|Cannot navigate away from this value|}
      end

    | Type.Record _, Query.Typed.Select (query, selection) ->
      let selectFrom value =
        let%bind _, dataset =
          let build (idx, dataset) { Query.Typed. alias; query; } =
            let%bind selectionValue = aux ~value query in
            let selectionAlias = Option.getWithDefault (string_of_int idx) alias in
            Js.Dict.set dataset selectionAlias selectionValue;
            return (idx + 1, dataset)
          in
          Run.List.foldLeft ~f:build ~init:(0, Js.Dict.empty ()) selection
        in
        return (Value.obj dataset)
      in
      let%bind value = aux ~value query in
      begin match Value.classify value with
      | Value.Object _ -> selectFrom value
      | Value.UI ui ->
        let%bind outQuery = Value.UI.outQuery ui in
        let queryValue = Value.UI.value ui in
        let%bind value = aux ~value:queryValue outQuery in
        selectFrom value
      | Value.Array items ->
        let%bind items = Run.Array.map ~f:selectFrom items in
        return (Value.array items)
      | Value.Null ->
        return Value.null
      | _ ->
        Js.log3 "ERROR" "cannot select from this value" value;
        executionError "cannot select from here"
      end
    | _, Query.Typed.Select _ ->
      executionError "invalid type for select"

    | _, Query.Typed.Locate (parent, id) ->
      let%bind parent = aux ~value parent in
      begin match Value.classify parent with
      | Value.Null ->
        return Value.null
      | Value.Array items ->
        let%bind id = aux ~value id in
        let f v =
          match Value.get ~name:"id" v with
          | Some v -> v = id
          | None -> false
        in
        return (Value.ofOption (Js.Array.find f items))
      | _ ->
        Js.log3 "ERROR:" "expected array but got" (Js.typeof parent);
        executionError {j|expected array|j}
      end

    | _, Query.Typed.Meta ((_,ctyp),_) ->
      return (Value.ofCtyp ctyp)

    | _, Query.Typed.Grow (parent, next) ->
      let%bind value = aux ~value parent in
      let%bind value = aux ~value next in
      return value

    | _, Query.Typed.Compare {Query.Typed. op; left; right;} ->
      let%bind left = aux ~value left in
      let%bind right = aux ~value right in
      let exec = function
        | Query.Operator.Equal -> (=)
        | Query.Operator.NotEqual -> (<>)
        | Query.Operator.LessThan -> (<)
        | Query.Operator.LessThanOrEqual -> (<=)
        | Query.Operator.GreaterThan -> (>)
        | Query.Operator.GreaterThanOrEqual -> (>=)
      in
      begin
        match Value.classify left, Value.classify right with
        | Value.Number left, Value.Number right ->
          return (Value.bool ((exec op) left right))
        | Value.Null, Value.Number _
        | Value.Number _, Value.Null
        | Value.Null, Value.Null ->
          return Value.null
        | _ ->
          executionError "'<' type mismatch ..."
      end

  and expandRef value =
    let resolveRef value =
      match parseRefOpt value with
      | Some ref ->
        let resolved =
          let open! Option.Syntax in
          let%bind coll = Value.get ~name:ref.refEntityName db.value in
          let%bind value = Value.get ~name:ref.refEntityId coll in
          return value
        in
        begin match resolved with
        | Some value -> return value
        | None -> executionError {j|unable to resolve ref $ref.refEntityName@ref.refEntityId|j}
        end
      | None -> return value
    in
    match Value.classify value with
    | Value.Object _ -> resolveRef value
    | Value.Array items ->
      let%bind items = Run.Array.map ~f:resolveRef items in
      return (Value.array items)
    | _ -> return value
  in

  let value = match value with
  | Some value -> value
  | None -> db.value
  in

  let%bind value = aux ~value query in
  let%bind value = expandRef value in

  let%bind value =
    let (_, ctyp), _ = query in
    formatValue ~ctyp value
  in

  return value