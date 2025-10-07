package main

import (
	"context"
	. "otuswork/projectwork/gen/internal"
	"testing"
)

var ctx context.Context = context.Background()

func TestMsgID(t *testing.T) {
	err := PgConn.
		QueryRow(ctx, `SELECT peek_nextval('messages_id_seq')`).
		Scan(&msgID)
	ExitIfError(err)
}
