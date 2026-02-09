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

//func init() {
//	rootCmd.CompletionOptions.DisableDefaultCmd = true
//}

func Execute() {
	// 1) Capture Cobra's default help template BEFORE overriding anything.
	defaultTemplate := rootCmd.HelpTemplate()

	// 2) Use your custom landing page ONLY for `odev`
	rootCmd.SetHelpTemplate(helpTemplate)

	// 3) Restore default help for all subcommands (so `odev new --help` is correct)
	applyHelpTemplateRecursively(rootCmd, defaultTemplate, true)

	_ = rootCmd.Execute()
}

// If skipRoot=true, it won't overwrite root's custom landing page.
func applyHelpTemplateRecursively(cmd *cobra.Command, tmpl string, skipRoot bool) {
	for _, c := range cmd.Commands() {

		// ✅ TINY FIX: only overwrite if the command is inheriting the parent's template
		if c.HelpTemplate() == cmd.HelpTemplate() {
			// skipRoot only matters for the first level when cmd == rootCmd
			if !(skipRoot && cmd == rootCmd) {
				c.SetHelpTemplate(tmpl)
			} else {
				// root's direct children should get default template
				c.SetHelpTemplate(tmpl)
			}
		}

		applyHelpTemplateRecursively(c, tmpl, false)
	}
}

const helpTemplate = `{{with .Short}}{{.}}

{{end}}` + bold + `USAGE` + reset + `
  {{.CommandPath}} <command> <subcommand> [flags]

` + bold + `COMMANDS` + reset + `
{{range .Commands}}{{if .IsAvailableCommand}}  {{rpad .Name 12}}{{.Short}}
{{end}}{{end}}
` + bold + `FLAGS` + reset + `
  {{rpad "--help" 12}}Show help for command
  {{rpad "--version" 12}}Show odev version

` + bold + `EXAMPLES` + reset + `
  $ odev new nccl
  $ odev examine

` + bold + `LEARN MORE` + reset + `
  Use ` + "`odev <command> <subcommand> --help`" + ` for more information about a command.
  Read the manual at https://books.oreol.ch/6/cli
`
