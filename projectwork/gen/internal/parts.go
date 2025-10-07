package internal

import (
	"bytes"

	"github.com/brianvoe/gofakeit/v7"
	"github.com/fpawel/mime"
)

// FakeParts 6 партов 4 парта с атачом
func FakeParts() []*mime.Part {
	mb := mime.NewMessageBuilder()

	mb.SetBody("text/pdf", "")
	mb.SetHeader("Subject", gofakeit.Sentence(5))
	mb.SetHeader("From", gofakeit.Email())
	mb.SetHeader("To", gofakeit.Email())

	for i := 0; i < 2; i++ {
		mb.Embedded = append(mb.Embedded, fakeMIMEFileInfo())
		mb.Attachments = append(mb.Attachments, fakeMIMEFileInfo())
	}
	buf := new(bytes.Buffer)
	_, _ = mb.WriteTo(buf)

	m, err := mime.Parse(buf.Bytes())
	ExitIfError(err)
	return m.Parts
}

func fakeMIMEFileInfo() mime.FileInfo {
	return mime.FileInfo{
		Name: gofakeit.Word() + "." + gofakeit.FileExtension(),
	}
}
