package main

import (
	"context"
	"fmt"
	. "otuswork/projectwork/gen/internal"
	"strings"
	"time"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/fpawel/ipsumru"
	"github.com/georgysavva/scany/v2/pgxscan"
	"github.com/jackc/pgx/v5"
)

func fakeDate() time.Time {
	return gofakeit.DateRange(time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC), time.Now())
}

func fakeSnippet(ruGen *ipsumru.SentenceGenerator) string {
	var b strings.Builder
	for i := 0; i < 10; i++ {
		if i != 0 {
			b.WriteString(" ")
		}
		_, _ = fmt.Fprintf(&b, "%s %s", ruGen.NextSentence(), gofakeit.HipsterSentence(10))
	}
	return b.String()
}

func main() {
	ruGen, err := ipsumru.NewSentenceGenerator()
	ExitIfError(err, "ipsumru")

	ctx := context.Background()
	var snippetsRows [][]any

	var msgIDs []int64
	err = pgxscan.Select(ctx, PgConn, &msgIDs, `SELECT COALESCE(msg_id,0) FROM messages`)
	ExitIfError(err)

	for _, msgID := range msgIDs {
		snippetsRows = append(snippetsRows, []any{
			msgID,
			fakeSnippet(ruGen),
		})
	}

	_, err = PgConn.CopyFrom(ctx,
		pgx.Identifier{"snippets"},
		[]string{"msg_id", "snippet"},
		pgx.CopyFromRows(snippetsRows))
	ExitIfError(err)
}
