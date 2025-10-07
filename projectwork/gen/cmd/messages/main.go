package main

import (
	"context"
	"fmt"
	"log/slog"
	. "otuswork/projectwork/gen/internal"
	"strings"
	"time"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/fpawel/ipsumru"
	"github.com/jackc/pgx/v5"

	"crypto/rand"
)

func fakeDate() time.Time {
	return gofakeit.DateRange(time.Date(2020, 1, 1, 0, 0, 0, 0, time.UTC), time.Now())
}

func fakeSnippet() string {
	var b strings.Builder
	for i := 0; i < 10; i++ {
		if i != 0 {
			b.WriteString(" ")
		}
		_, _ = fmt.Fprintf(&b, "%s %s", ruGen.NextSentence(), gofakeit.HipsterSentence(10))
	}

	return b.String()
}

var (
	ruGen, errRuGen = ipsumru.NewSentenceGenerator()

	userTags = GetUserTags()

	ctx = context.Background()

	messagesRows       [][]any
	snippetsRows       [][]any
	messagesStatusRows [][]any
	objectRows         [][]any
	partsRows          [][]any
)

var (
	nextID struct {
		objects  int64
		messages int64
		parts    int64
	}
)

func initNextObjID() {
	err := PgConn.
		QueryRow(ctx, `SELECT peek_nextval('s3_objects_id_seq')`).
		Scan(&nextID.objects)
	ExitIfError(err)
}

func initNextMsgID() {
	err := PgConn.
		QueryRow(ctx, `SELECT peek_nextval('messages_msg_id_seq')`).
		Scan(&nextID.messages)
	ExitIfError(err)
}

func RandomSHA256() []byte {
	buf := make([]byte, 32) // SHA256 = 32 байта
	_, err := rand.Read(buf)
	ExitIfError(err)
	return buf
}

func addObjectID(ext string) (ret int64) {
	// "bucket_id", "object_key", "version", "size", "sha256"
	objectRows = append(objectRows, []any{
		gofakeit.IntRange(1, 5),
		gofakeit.UUID() + ext,
		gofakeit.UUID() + ".version",
		gofakeit.IntRange(1_000, 100_000_000),
		RandomSHA256(),
	})
	ret = nextID.objects
	nextID.objects++
	return
}

func copyObjectsFrom() {
	_, err := PgConn.CopyFrom(ctx,
		pgx.Identifier{"s3_objects"}, []string{"bucket_id", "object_key", "version", "size", "sha256"},
		pgx.CopyFromRows(objectRows))
	ExitIfError(err)
	objectRows = nil
	initNextObjID()
}

func copyMessagesFrom() {
	_, err := PgConn.CopyFrom(ctx,
		pgx.Identifier{"messages"},
		[]string{"tag_id", "object_id"},
		pgx.CopyFromRows(messagesRows))
	ExitIfError(err)
	messagesRows = nil
}

func copyMessagesStatusesFrom() {
	_, err := PgConn.CopyFrom(ctx,
		pgx.Identifier{"messages_status"},
		[]string{"msg_id", "time", "tag_id", "status"},
		pgx.CopyFromRows(messagesStatusRows))
	ExitIfError(err)
	messagesStatusRows = nil
}

func copySnippetsFrom() {
	_, err := PgConn.CopyFrom(ctx,
		pgx.Identifier{"snippets"},
		[]string{"msg_id", "snippet"},
		pgx.CopyFromRows(snippetsRows))
	ExitIfError(err)
	snippetsRows = nil
}

func copyPartsFrom() {
	_, err := PgConn.CopyFrom(ctx,
		pgx.Identifier{"parts"}, []string{"msg_id", "children", "part_order", "object_id", "headers"},
		pgx.CopyFromRows(partsRows))
	ExitIfError(err)
}

func addMessage(tagID int64) (newMsgID int64) {
	// "tag_id object_id snippet
	messagesRows = append(messagesRows, []any{
		tagID,
		addObjectID(".eml"),
	})

	for _, p := range FakeParts() {
		partsRows = append(partsRows, []any{
			nextID.messages,
			p.Children,
			p.Order,
			addObjectID(".part"),
			p.Header,
		})
		nextID.parts++
	}

	newMsgID = nextID.messages
	nextID.messages++
	return newMsgID
}

func main() {
	ExitIfError(errRuGen, "ipsumru")
	initNextObjID()
	initNextMsgID()

	err := PgConn.
		QueryRow(ctx, `SELECT peek_nextval('parts_part_id_seq')`).
		Scan(&nextID.parts)
	ExitIfError(err)

	// черновики
	for _, ut := range userTags {
		newMsgID := addMessage(ut.Drafts)
		messagesStatusRows = append(messagesStatusRows, []any{
			newMsgID,
			fakeDate(),
			ut.Drafts,
			"created",
		})

		snippetsRows = append(snippetsRows, []any{
			newMsgID,
			fakeSnippet(),
		})
	}

	slog.Info("Copying objects")
	copyObjectsFrom()
	slog.Info("Copying messages")
	copyMessagesFrom()
	slog.Info("Copying messages status")
	copyMessagesStatusesFrom()
	slog.Info("Copying snippets")
	copySnippetsFrom()
	slog.Info("Copying parts")
	copyPartsFrom()
}
