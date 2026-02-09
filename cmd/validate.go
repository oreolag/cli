package cmd

import (
	validatecmd "oreolag/cli/cmd/validate"

	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Infrastructure functionality assessment",
}

func init() {
	validateCmd.SetHelpTemplate(validateHelpTemplate)

	rootCmd.AddCommand(validateCmd)
	validateCmd.AddCommand(validatecmd.NcclCmd)
}

const validateHelpTemplate = `{{with .Short}}{{.}}

{{end}}Usage:
  {{.CommandPath}} [command]

Available Commands:
{{range .Commands}}{{if .IsAvailableCommand}}  {{rpad .Name 12}}{{.Short}}
{{end}}{{end}}
Flags:
  {{rpad "-h, --help" 12}}help for {{.Name}}

Use "{{.CommandPath}} [command] --help" for more information about a command.
`
