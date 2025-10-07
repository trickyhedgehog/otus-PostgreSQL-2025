package main

import (
	"context"
	"otuswork/projectwork/gen/internal"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/jackc/pgx/v5"
)

func main() {
	ctx := context.Background()

	var bucketRows [][]any
	for i := 0; i < 5; i++ {
		bucketRows = append(bucketRows, []any{
			"bucket-" + gofakeit.Word(),
			gofakeit.Country(),
		})
	}
	_, err := internal.PgConn.CopyFrom(ctx,
		pgx.Identifier{"s3_buckets"}, []string{"name", "region"},
		pgx.CopyFromRows(bucketRows))
	internal.ExitIfError(err)
}
