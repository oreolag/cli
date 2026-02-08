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

func init() {
	rootCmd.CompletionOptions.DisableDefaultCmd = true
}

func Execute() {
	rootCmd.SetHelpTemplate(helpTemplate)
	_ = rootCmd.Execute()
}

const helpTemplate = `{{with .Short}}{{.}}

{{end}}` + "\x1b[1m" + `USAGE` + "\x1b[0m" + `
  {{.CommandPath}} <command> <subcommand> [flags]

` + "\x1b[1m" + `COMMANDS` + "\x1b[0m" + `
{{range .Commands}}{{if .IsAvailableCommand}}  {{rpad .Name .NamePadding }}{{.Short}}
{{end}}{{end}}
` + "\x1b[1m" + `FLAGS` + "\x1b[0m" + `
  --help         Show help for command
  --version      Show odev version

` + "\x1b[1m" + `EXAMPLES` + "\x1b[0m" + `
  $ odev new nccl
  $ odev examine

` + "\x1b[1m" + `LEARN MORE` + "\x1b[0m" + `
  Use ` + "`odev <command> <subcommand> --help`" + ` for more information about a command.
  Read the manual at https://books.oreol.ch/6/cli
`
