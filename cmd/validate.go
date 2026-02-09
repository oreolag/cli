package cmd

import (
	validatecmd "oreolag/cli/cmd/validate"

	"github.com/spf13/cobra"
)

var validateCmd = &cobra.Command{
	Use:   "validate",
	Short: "Validate a project",
}

func init() {
	rootCmd.AddCommand(validateCmd)

	// Attach subcommands: odev validate nccl
	validateCmd.AddCommand(validatecmd.NcclCmd)
}
