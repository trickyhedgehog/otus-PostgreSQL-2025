package main

import (
	"context"
	"encoding/json"
	"otuswork/projectwork/gen/internal"
	"strings"
	"time"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/jackc/pgx/v5"
)

func main() {
	// Слайс для хранения строк перед вставкой в базу данных
	var rows [][]any

	users := map[string]bool{}

	for i := 0; i < 100_000; i++ {
		username := strings.ToLower(gofakeit.Username())
		for users[username] {
			username = strings.ToLower(gofakeit.Username())
		}
		users[username] = true

		dataJSON, _ := json.Marshal(map[string]any{
			"first_name":  gofakeit.FirstName(),
			"last_name":   gofakeit.LastName(),
			"middle_name": gofakeit.MiddleName(),
			"gender":      gofakeit.Gender(),
			"address":     gofakeit.Address(),
			"phone":       gofakeit.Phone(),
			"job":         gofakeit.Job(),
			"ssn":         gofakeit.SSN(),
			"hobby":       gofakeit.Hobby(),
			"company":     gofakeit.Company(),
			"contact":     gofakeit.Contact(),
			"credit_card": gofakeit.CreditCard(),
		})

		rows = append(rows, []any{
			username + "@" + gofakeit.DomainName(),
			username,
			gofakeit.DateRange(
				time.Date(2010, 1, 1, 1, 1, 1, 1, time.UTC),
				gofakeit.PastDate(),
			),
			string(dataJSON),
		})
	}

	ctx := context.Background()
	_, err := internal.PgConn.CopyFrom(ctx,
		pgx.Identifier{"users"}, []string{"email", "login", "created_at", "data"},
		pgx.CopyFromRows(rows))
	internal.ExitIfError(err)
}
