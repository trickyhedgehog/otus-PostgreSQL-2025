package main

import (
	"context"
	"math/rand"
	. "otuswork/projectwork/gen/internal"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/georgysavva/scany/v2/pgxscan"
	"github.com/jackc/pgx/v5"
)

func main() {
	ctx := context.Background()

	var userIDGen IDGen
	err := pgxscan.Select(ctx, PgConn, &userIDGen.IDs, `SELECT COALESCE(user_id,0) FROM users`)
	ExitIfError(err)

	var objIDMin int64
	err = PgConn.
		QueryRow(ctx, `SELECT peek_nextval('s3_objects_id_seq')`).
		Scan(&objIDMin)
	ExitIfError(err)

	var msgIDs []int64
	err = pgxscan.Select(ctx, PgConn, &msgIDs, `SELECT COALESCE(msg_id,0) FROM messages`)
	ExitIfError(err)

	var objectRows [][]any

	for range msgIDs {
		for range make([]struct{}, 4) {
			bucketID := rand.Intn(5) + 1
			objectRows = append(objectRows, []any{
				bucketID,
				gofakeit.UUID() + ".part",
				nil,
				rand.Intn(50000) + 500, // size
				gofakeit.HexUint(256),
			})
		}
	}

	_, err = PgConn.CopyFrom(ctx,
		pgx.Identifier{"s3_objects"}, []string{"bucket_id", "object_key", "version", "size", "sha256"},
		pgx.CopyFromRows(objectRows))
	ExitIfError(err)

	objIDGen := NewIDGen(objIDMin, objIDMin+int64(len(msgIDs)*4)-1)

	var partsRows [][]any
	for _, msgID := range msgIDs {
		for _, p := range FakeParts() {
			var objID any = nil
			if len(p.Children) == 0 {
				objID = objIDGen.Get()
			}
			partsRows = append(partsRows, []any{
				msgID,
				p.Children,
				p.Order,
				objID,
				p.Header,
			})

		}
	}

	_, err = PgConn.CopyFrom(ctx,
		pgx.Identifier{"parts"}, []string{"msg_id", "children", "part_order", "object_id", "headers"},
		pgx.CopyFromRows(partsRows))
	ExitIfError(err)
}
