package cmd

import "github.com/spf13/cobra"

const (
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

{{end}}USAGE
  {{.CommandPath}} <command> [flags]

COMMANDS
{{range .Commands}}{{if .IsAvailableCommand}}
  {{rpad .Name .NamePadding }}{{.Short}}{{end}}{{end}}

Run "{{.CommandPath}} <command> --help" for more information.
`
