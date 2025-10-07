package internal

import (
	"context"
	"log/slog"
	"time"

	"github.com/georgysavva/scany/v2/pgxscan"
)

type UserTags struct {
	UserID      int64 `db:"user_id"`
	Inbox       int64 `db:"inbox_tag_id"`
	Sent        int64 `db:"sent_tag_id"`
	Trash       int64 `db:"trash_tag_id"`
	Junk        int64 `db:"junk_tag_id"`
	Drafts      int64 `db:"drafts_tag_id"`
	Work        int64 `db:"work_tag_id"`
	Projects    int64 `db:"projects_tag_id"`
	Reports     int64 `db:"reports_tag_id"`
	Personal    int64 `db:"personal_tag_id"`
	Newsletters int64 `db:"newsletters_tag_id"`
}

func GetUserTags() (r []UserTags) {
	ctx := context.Background()
	tm := time.Now()
	err := pgxscan.Select(ctx, PgConn, &r, ` SELECT * FROM user_mailboxes`)
	ExitIfError(err)
	slog.Info("Done processing user tags", "time", time.Since(tm).String(), "users", len(r))
	return r
}
