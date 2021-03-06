open! Jest
open! Expect
open! Expect.Operators

module Q = Query.Untyped.Syntax
module M = Query.Mutation.Syntax

let liftResult = function
  | Js.Result.Ok v -> Run.return v
  | Js.Result.Error err -> Run.error (`DatabaseError err)

let liftOption ~err = function
  | Some v -> Run.return v
  | None -> Run.error (`DatabaseError err)

let univ =
  let rec nation = lazy Query.Type.Syntax.(
    entity "nation" (fun _ -> [
      hasOne "id" string;
      hasOne "name" string;
      hasOne "region" (Lazy.force region);
    ])
  )
  and region = lazy Query.Type.Syntax.(
    entity "region" (fun _ -> [
      hasOne "id" string;
      hasOne "name" string;
      hasMany "nation" (Lazy.force nation);
    ])
  )
  in
  Core.Universe.(
    empty
    |> hasMany "region" (Lazy.force region)
    |> hasMany "nation" (Lazy.force nation)
    |> hasScreen "pick" JsApi.pickScreen
    |> hasScreen "view" JsApi.viewScreen
  )

let getDb () =
  JSONDatabase.ofStringExn ~univ {|
    {
      "region": {
        "AMERICA": {
          "id": "AMERICA",
          "name": "America",
          "nation": [
            {"$ref": {"entity": "nation", "id": "US"}}
          ]
        },
        "ASIA": {
          "id": "ASIA",
          "name": "Asia",
          "nation": [
            {"$ref": {"entity": "nation", "id": "RUSSIA"}},
            {"$ref": {"entity": "nation", "id": "CHINA"}}
          ]
        }
      },

      "nation": {
        "US": {
          "id": "US",
          "name": "United States of America",
          "region": {"$ref": {"entity": "region", "id": "AMERICA"}}
        },
        "CHINA": {
          "id": "CHINA",
          "name": "China",
          "region": {"$ref": {"entity": "region", "id": "ASIA"}}
        },
        "RUSSIA": {
          "id": "RUSSIA",
          "name": "Russia",
          "region": {"$ref": {"entity": "region", "id": "ASIA"}}
        }
      }
    }
  |}

let expectDbToMatchSnapshot db =
  expect(JSONDatabase.root db) |> toMatchSnapshot

let runQuery ~db q =
  let open Run.Syntax in
  let%bind q = Core.QueryTyper.typeQuery ~univ q in
  let%bind r = JSONDatabase.query ~db q in
  return r

let unwrapAssertionResult v = match Run.toResult v with
  | Common.Result.Ok assertion -> assertion
  | Common.Result.Error (`DatabaseError err) -> fail {j|DatabaseError: $err|j}
  | Common.Result.Error (`QueryTypeError err) -> fail {j|QueryTypeError: $err|j}

let runQueryAndExpect ~db q v =
  unwrapAssertionResult (
    let open Run.Syntax in
    let%bind r = runQuery ~db q in
    return (expect(r) |> toEqual(v))
  )

let expectOk comp = match Run.toResult comp with
  | Common.Result.Ok _ -> pass
  | Common.Result.Error (`DatabaseError err) -> fail err
  | Common.Result.Error (`QueryTypeError err) -> fail err

let valueOfStringExn s = s |> Js.Json.parseExn |> Value.ofJson

let () =

  describe "JSONDatabase.query" begin fun () ->

    let db = getDb () in

    test "/" begin fun () ->
      let q = Q.(void) in
      runQueryAndExpect ~db q (JSONDatabase.root db)
    end;

    test "/region" begin fun () ->
      let q = Q.(void |> nav "region") in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {
            "id": "AMERICA",
            "name": "America"
          },
          {
            "id": "ASIA",
            "name": "Asia"
          }
        ]
      |})
    end;

    test "/region.name" begin fun () ->
      let q = Q.(void |> nav "region" |> nav "name") in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          "America",
          "Asia"
        ]
      |})
    end;

    test "region { label: name }" begin fun () ->
      let q = Q.(
        here
        |> nav "region"
        |> select [
          field ~alias:"label" (here |> nav "name");
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {
            "label": "America"
          },
          {
            "label": "Asia"
          }
        ]
      |})
    end;

    test "region { nation { label: name } }" begin fun () ->
      let q = Q.(
        here
        |> nav "region"
        |> select [
          field ~alias:"nation" (
            here
            |> nav "nation"
            |> select [
              field ~alias:"label" (here |> nav "name");
            ]
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {"nation": [{"label": "United States of America"}]},
          {"nation": [{"label": "Russia"}, {"label": "China"}]}
        ]
      |})
    end;

    test "{ regions: region }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"regions" (here |> nav "region");
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "regions": [
            {
              "id": "AMERICA",
              "name": "America"
            },
            {
              "id": "ASIA",
              "name": "Asia"
            }
          ]
        }
      |})
    end;

    test "{ regionNames: region.name }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"regionNames" (here |> nav "region" |> nav "name");
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "regionNames": [
            "America",
            "Asia"
          ]
        }
      |})
    end;

    test "/region[\"ASIA\"]" begin fun () ->
      let q = Q.(void |> nav "region" |> locate (string "ASIA")) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "id": "ASIA",
          "name": "Asia"
        }
      |})
    end;

    test "/region[\"ASIA\"].nation" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> locate (string "ASIA")
        |> nav "nation"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {"id": "RUSSIA", "name": "Russia"},
          {"id": "CHINA", "name": "China"}
        ]
      |})
    end;

    test "/region[\"ASIA\"].nation.name" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> locate (string "ASIA")
        |> nav "nation"
        |> nav "name"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          "Russia",
          "China"
        ]
      |})
    end;

    test "{ asia: region[\"ASIA\"] }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"asia" (
            here
            |> nav "region"
            |> locate (string "ASIA")
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "asia": {
            "id": "ASIA",
            "name": "Asia"
          }
        }
      |})
    end;

    test "{ asia: region[\"ASIA\"].name }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"asia" (
            here
            |> nav "region"
            |> locate (string "ASIA")
            |> nav "name"
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "asia": "Asia"
        }
      |})
    end;

    test "{ asiaNations: region[\"ASIA\"].nation }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"asiaNations" (
            here
            |> nav "region"
            |> locate (string "ASIA")
            |> nav "nation"
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "asiaNations": [
            {"id": "RUSSIA", "name": "Russia"},
            {"id": "CHINA", "name": "China"}
          ]
        }
      |})
    end;

    test "{ asiaNationNames: region[\"ASIA\"].nation.name }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"asiaNationNames" (
            here
            |> nav "region"
            |> locate (string "ASIA")
            |> nav "nation"
            |> nav "name"
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "asiaNationNames": [
            "Russia",
            "China"
          ]
        }
      |})
    end;

    test "{ data: region[\"ASIA\"] { nations: nation } }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"data" (
            here
            |> nav "region"
            |> locate (string "ASIA")
            |> select [
              field ~alias:"nations" (
                here
                |> nav "nation"
              )
            ]
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "data": {
            "nations": [
              {"id": "RUSSIA", "name": "Russia"},
              {"id": "CHINA", "name": "China"}
            ]
          }
        }
      |})
    end;

    test "{ data: region[\"ASIA\"] { nationNames: nation.name } }" begin fun () ->
      let q = Q.(
        here
        |> select [
          field ~alias:"data" (
            here
            |> nav "region"
            |> locate (string "ASIA")
            |> select [
              field ~alias:"nationNames" (
                here
                |> nav "nation"
                |> nav "name"
              )
            ]
          )
        ]
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "data": {
            "nationNames": [
              "Russia",
              "China"
            ]
          }
        }
      |})
    end;

    test "region.nation.region" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> nav "nation"
        |> nav "region"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {
            "id": "AMERICA",
            "name": "America"
          },
          {
            "id": "ASIA",
            "name": "Asia"
          },
          {
            "id": "ASIA",
            "name": "Asia"
          }
        ]
      |})
    end;

    test "region:pick.data" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen "pick"
        |> nav "data"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {
            "id": "AMERICA",
            "name": "America"
          },
          {
            "id": "ASIA",
            "name": "Asia"
          }
        ]
      |})
    end;

    test "region:pick(id: 'ASIA').data" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen ~args:[arg "id" (string "ASIA")] "pick"
        |> nav "data"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        [
          {
            "id": "AMERICA",
            "name": "America"
          },
          {
            "id": "ASIA",
            "name": "Asia"
          }
        ]
      |})
    end;

    test "region:pick.value" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen "pick"
        |> nav "value"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        null
      |})
    end;

    test "region:pick(id: 'ASIA').value" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen ~args:[arg "id" (string "ASIA")] "pick"
        |> nav "value"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "id": "ASIA",
          "name": "Asia"
        }
      |})
    end;

    test "region:pick(id: 'ASIA').value:view.value" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen ~args:[arg "id" (string "ASIA")] "pick"
        |> nav "value"
        |> screen "view"
        |> nav "value"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "id": "ASIA",
          "name": "Asia"
        }
      |})
    end;

    test "region:pick(id: 'ASIA').value:view.data" begin fun () ->
      let q = Q.(
        void
        |> nav "region"
        |> screen ~args:[arg "id" (string "ASIA")] "pick"
        |> nav "value"
        |> screen "view"
        |> nav "data"
      ) in
      runQueryAndExpect ~db q (valueOfStringExn {|
        {
          "id": "ASIA",
          "name": "Asia"
        }
      |})
    end;

  end;

  let createFormValue string =
    let v = Js.Json.parseExn string in
    Value.ofJson v
  in

  describe "JSONDatabase.updateEntity" begin fun () ->

    test "setValue" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "region"
          |> locate (string "ASIA")
          |> update [
            "name", M.update (Q.string "UPDATED")
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let%bind () = Mutation.execute mut Value.null in
        return (expectDbToMatchSnapshot db)
      )
    end;

    test "updateEntity" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "nation"
          |> locate (string "CHINA")
          |> update [
            "region", M.updateEntity [
              "name", M.update (Q.string "UPDATED");
            ]
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let%bind () = Mutation.execute mut Value.null in
        return (expectDbToMatchSnapshot db)
      )

    end;

    test "createEntity" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "nation"
          |> locate (string "CHINA")
          |> update [
              "region", M.createEntity [
                "name", M.update (Q.string "NEWREGION");
              ]
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let%bind () = Mutation.execute mut Value.null in
        return (expectDbToMatchSnapshot db)
      )

    end;

  end;

  describe "JSONDatabase.createEntity" begin fun () ->

    test "simple" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "region"
          |> create [
            "name", M.update (string "NEWREGION");
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let%bind () = Mutation.execute mut Value.null in
        return (expectDbToMatchSnapshot db)
      )

    end;

    test "simple with query" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "region"
          |> create [
            "name", M.update (here |> nav "nation" |> locate (string "RUSSIA") |> nav "name");
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let value = Value.null in
        let%bind () = Mutation.execute mut value in
        return (expectDbToMatchSnapshot db)
      )

    end;

    test "simple with $value" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "region"
          |> create [
            "name", M.update (name "value" |> nav "name");
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let value = createFormValue {|
          {"name": "HEY"}
        |} in
        let%bind () = Mutation.execute mut value in
        return (expectDbToMatchSnapshot db)
      )

    end;

    test "with nested" begin fun () ->
      let db = getDb () in

      unwrapAssertionResult (
        let open Run.Syntax in
        let query = Q.(
          void
          |> nav "nation"
          |> create [
            "name", M.update (Q.string "NEWNATION");
            "region", M.createEntity [
              "name", M.update (Q.string "NEWREGION");
            ]
          ]
        ) in
        let%bind query = QueryTyper.typeQuery ~univ query in
        let%bind res = JSONDatabase.query ~db query in
        let%bind mut = liftOption ~err:"expected mutation" (Value.decodeMutation res) in
        let%bind () = Mutation.execute mut Value.null in
        return (expectDbToMatchSnapshot db)
      )

    end;

  end;
