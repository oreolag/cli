package cmd

import "github.com/spf13/cobra"

const (
	bold   = "\x1b[1m"
	italic = "\x1b[3m"
	reset  = "\x1b[0m"
)

var rootCmd = &cobra.Command{
	Use:   "odev",
	Short: "The CLI for hetero" + italic + "genius" + reset + " computing.",
}

func Execute() {
	rootCmd.SetHelpTemplate(helpTemplate)
	_ = rootCmd.Execute()
}

const helpTemplate = `{{with .Short}}{{.}}

{{end}}` + "\x1b[1m" + `USAGE` + "\x1b[0m" + `
  {{.CommandPath}} <command> <subcommand> [flags]

` + "\x1b[1m" + `COMMANDS` + "\x1b[0m" + `
{{range .Commands}}{{if .IsAvailableCommand}}  {{.Name}}
{{end}}{{end}}

Run "{{.CommandPath}} <command> --help" for more information.
`
