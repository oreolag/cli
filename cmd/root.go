package cmd

import "github.com/spf13/cobra"

var rootCmd = &cobra.Command{
	Use:   "odev",
	Short: "Work seamlessly with heterogeneous systems from the command line.",
}

func Execute() {
	rootCmd.SetHelpTemplate(helpTemplate)
	_ = rootCmd.Execute()
}

const helpTemplate = `{{with .Short}}{{.}}

{{end}}USAGE
  {{.CommandPath}} <command> [flags]

COMMANDS
{{range .Commands}}{{if (and .IsAvailableCommand (not .IsHelpCommand))}}
  {{rpad .Name .NamePadding }}{{.Short}}{{end}}{{end}}

Run "{{.CommandPath}} <command> --help" for more information.
`
