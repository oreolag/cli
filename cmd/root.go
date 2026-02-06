package cmd

import "github.com/spf13/cobra"

var rootCmd = &cobra.Command{
	Use: "odev",
}

func Execute() {
	_ = rootCmd.Execute()
}