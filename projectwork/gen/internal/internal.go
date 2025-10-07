package internal

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/fpawel/slogx/slogctx"
	"github.com/fpawel/slogx/slogpretty"
	"github.com/jackc/pgx/v5"
)

const ConnStr = "postgresql://postgres:postgres@localhost:5432/maildb?sslmode=disable"

var PgConn *pgx.Conn

func ExitIfError(err error, args ...any) {
	if err == nil {
		return
	}
	if len(args) == 1 {
		slog.Error(fmt.Sprintf("%v: %s", args[0], err))
	} else {
		slog.Error(err.Error(), args...)
	}
	os.Exit(1)
}

func init() {
	logLevel := slog.LevelInfo
	if os.Getenv("DEBUG") != "" {
		logLevel = slog.LevelDebug
	}
	slog.SetDefault(
		slog.New(
			slogctx.NewHandler(
				slogpretty.NewPrettyHandler().
					WithSourceInfo(false).
					WithLogLevel(logLevel))))

	// Подключение к базе данных PostgreSQL
	ctx := context.Background()
	// Устанавливаем подключение
	var err error
	PgConn, err = pgx.Connect(ctx, ConnStr)
	// Если ошибка подключения, выводим сообщение и завершаем программу
	ExitIfError(err, "connect to database")
}
